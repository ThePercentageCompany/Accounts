import { requireThat } from './errors.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
// Initial ledger contract: two decimal places. Reject unsupported precision rather
// than silently rounding a journal into balance. Integer sums use BigInt.
function minor(value) {
  requireThat(typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1e12,
    400, 'INVALID_JOURNAL_AMOUNT', 'Journal amounts must be nonnegative numbers.');
  const text = String(value);
  requireThat(/^\d+(?:\.\d{1,2})?$/.test(text), 400, 'INVALID_JOURNAL_AMOUNT', 'Journal amounts support two decimal places.');
  const [whole, fraction = ''] = text.split('.');
  return BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
}
function lineAmounts(line) {
  const debit = minor(line.debit === '' || line.debit === undefined ? 0 : line.debit);
  const credit = minor(line.credit === '' || line.credit === undefined ? 0 : line.credit);
  requireThat((debit > 0n) !== (credit > 0n), 400, 'INVALID_JOURNAL_LINE', 'Each line must have exactly one positive debit or credit.');
  requireThat(typeof line.accountId === 'string' && line.accountId.trim().length > 0 &&
    Number.isSafeInteger(line.lineNumber) && line.lineNumber > 0,
  400, 'INVALID_JOURNAL_LINE', 'Each line needs an account and positive integer line number.');
  return { debit, credit };
}

export async function validateJournal(sheets, companyId, table, recordId, action, old, values) {
  if (!['Journals', 'JournalLines'].includes(table)) return;
  const next = { ...old, ...values };
  if (table === 'JournalLines') {
    const rows = (await sheets.read(companyId, ['Journals'])).Journals;
    for (const journalId of new Set([old?.journalId, next.journalId].filter(Boolean))) {
      const journal = rows.find(row => row.recordId === journalId && row.companyId === companyId && active(row));
      requireThat(journal?.status === 'DRAFT', 409, 'JOURNAL_LOCKED', 'Only draft journal lines can change.');
    }
    if (action !== 'delete') lineAmounts(next);
    return;
  }
  requireThat(!old || old.status === 'DRAFT', 409, 'JOURNAL_LOCKED', 'Posted or unknown-state journals cannot be edited or deleted.');
  if (action === 'delete') return;
  requireThat(['DRAFT', 'POSTED'].includes(next.status), 400, 'INVALID_JOURNAL_STATUS', 'Journal status must be DRAFT or POSTED.');
  requireThat(action !== 'create' || next.status === 'DRAFT', 400, 'INVALID_JOURNAL_STATUS', 'Create the draft and its lines before posting.');
  if (next.status !== 'POSTED') return;
  const lines = (await sheets.read(companyId, ['JournalLines'])).JournalLines.filter(row =>
    row.companyId === companyId && row.journalId === recordId && active(row));
  requireThat(lines.length >= 2, 409, 'JOURNAL_UNBALANCED', 'Posting requires at least two journal lines.');
  const numbers = new Set(); let debit = 0n, credit = 0n;
  for (const line of lines) {
    const amount = lineAmounts(line);
    requireThat(!numbers.has(line.lineNumber), 409, 'INVALID_JOURNAL_LINE', 'Journal line numbers must be unique.');
    numbers.add(line.lineNumber); debit += amount.debit; credit += amount.credit;
  }
  requireThat(debit === credit && debit > 0n && minor(next.totalDebit) === debit && minor(next.totalCredit) === credit,
    409, 'JOURNAL_UNBALANCED', 'Journal totals must equal the balanced line totals.');
}
