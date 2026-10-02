import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate } from './financial-period-policy.js';
import { validateJournal } from './journal-policy.js';

// Called under the company's business-write reservation. Rows are submitted
// atomically with the source marker; uncertain retries reconcile that marker.
export async function cashLedgerChanges(sheets, companyId, table, record, system, operation, settlementOnly = false) {
  const income = table === 'Income';
  const data = await sheets.read(companyId, ['Journals', 'JournalLines']);
  if (settlementOnly) {
    const related = data.Journals.filter(j => j.companyId === companyId && j.sourceId === record.recordId &&
      j.isDeleted !== true && j.isDeleted !== 'TRUE');
    const entries = related.filter(j => j.sourceType === table);
    requireThat(entries.length === 1 && entries[0].status === 'POSTED' && entries[0].date === record.date &&
      entries[0].totalDebit === record.total && entries[0].totalCredit === record.total &&
      !related.some(j => [ `${table}Payment`, `${table}Reversal` ].includes(j.sourceType)),
    409, 'PAYMENT_NOT_AVAILABLE', 'Payment requires one matching posted entry and no existing payment.');
    const postedLines = data.JournalLines.filter(l => l.companyId === companyId &&
      l.journalId === entries[0].recordId && l.isDeleted !== true && l.isDeleted !== 'TRUE');
    const account = income ? 'accounts_receivable' : 'accounts_payable';
    const controlLines = postedLines.filter(l => l.accountId === account);
    requireThat(controlLines.length === 1 &&
      controlLines[0][income ? 'debit' : 'credit'] === record.total &&
      controlLines[0][income ? 'credit' : 'debit'] === 0,
    409, 'PAYMENT_NOT_AVAILABLE', 'The posted control account does not match this entry.');
  }
  const next = Object.fromEntries(Object.entries(data).map(([name, rows]) =>
    [name, Math.max(1, ...rows.map(r => r._row)) + 1]));
  const changes = [];
  const line = (accountId, accountName, accountGroup, debit, credit) =>
    ({ accountId, accountName, accountGroup, debit, credit });
  const control = income ? ['accounts_receivable', 'Accounts Receivable', 'Asset'] :
    ['accounts_payable', 'Accounts Payable', 'Liability'];
  async function journal(kind, date, lines) {
    await assertOpenLedgerDate(sheets, companyId, date);
    const id = challenge(`${companyId}:${operation}:${kind}`);
    const total = record.total;
    changes.push({ table: 'Journals', row: next.Journals++, values: {
      ...system, recordId: id, recordVersion: 1, number: `AUTO-${id}`, date,
      description: record.description, sourceType: kind === 'entry' ? table : `${table}Payment`,
      sourceId: record.recordId, totalDebit: total, totalCredit: total, status: 'POSTED',
    } });
    lines.forEach((values, index) => changes.push({ table: 'JournalLines', row: next.JournalLines++, values: {
      ...system, recordId: challenge(`${id}:${index}`), recordVersion: 1,
      journalId: id, lineNumber: index + 1, ...values,
    } }));
  }
  const lines = income ? [line(...control, record.total, 0),
    line('other_income', 'Other Income', 'Income', 0, record.amount)] :
    [line('operating_expense', 'Operating Expense', 'Expense', record.amount, 0),
      line(...control, 0, record.total)];
  if (record.taxAmount > 0) lines.push(income ?
    line('output_vat_payable', 'Output VAT Payable', 'Liability', 0, record.taxAmount) :
    line('input_vat', 'Input VAT', 'Asset', record.taxAmount, 0));
  if (!settlementOnly) await journal('entry', record.date, lines);
  if (record.paymentStatus === 'PAID') {
    const account = String(record.account || '').trim().toLowerCase();
    requireThat(['cash', 'bank'].includes(account), 400, 'INVALID_PAYMENT_ACCOUNT', 'Select Cash or Bank before posting.');
    requireThat(record.paidDate >= record.date, 400, 'INVALID_PAYMENT_DATE', 'Payment cannot precede the entry date.');
    const cash = account === 'cash' ? ['cash_in_hand', 'Cash in Hand', 'Asset'] : ['bank_account', 'Bank Account', 'Asset'];
    await journal('payment', record.paidDate, income ?
      [line(...cash, record.total, 0), line(...control, 0, record.total)] :
      [line(...control, record.total, 0), line(...cash, 0, record.total)]);
  }
  return changes;
}

export async function reverseCashChanges(sheets, companyId, table, record, system, operation, values) {
  requireThat(['UNPAID', 'PAID'].includes(record.paymentStatus), 409, 'REVERSAL_NOT_AVAILABLE',
    'Only posted unpaid or paid entries can be reversed.');
  const data = await sheets.read(companyId, ['Journals', 'JournalLines']);
  const related = data.Journals.filter(j => j.companyId === companyId && j.sourceId === record.recordId &&
    j.isDeleted !== true && j.isDeleted !== 'TRUE' &&
    [table, `${table}Payment`, `${table}Reversal`, `${table}Refund`].includes(j.sourceType));
  const originals = related.filter(j => [table, `${table}Payment`].includes(j.sourceType));
  const expected = record.paymentStatus === 'PAID' ? [table, `${table}Payment`] : [table];
  requireThat(related.length === expected.length && originals.length === expected.length &&
    expected.every(type => originals.filter(j => j.sourceType === type && j.status === 'POSTED').length === 1),
  409, 'REVERSAL_NOT_AVAILABLE', 'The entry requires one matching posting and payment with no prior reversal.');
  requireThat(originals.every(original => values.date >= original.date), 400, 'INVALID_REVERSAL',
    'Reversal cannot precede the original posting or payment.');
  // Reuse exact decimal, unique-line and period validation, without changing the
  // original journal. Balanced originals remain balanced when sides are swapped.
  const changes = [];
  let journalRow = Math.max(1, ...data.Journals.map(r => r._row)) + 1;
  let lineRow = Math.max(1, ...data.JournalLines.map(r => r._row)) + 1;
  for (const original of originals.sort((a, b) => a.sourceType === table ? 1 : b.sourceType === table ? -1 : 0)) {
    await validateJournal(sheets, companyId, 'Journals', original.recordId, 'update', { status: 'DRAFT' },
      { status: 'POSTED', date: values.date, totalDebit: original.totalDebit, totalCredit: original.totalCredit });
    const lines = data.JournalLines.filter(l => l.companyId === companyId && l.journalId === original.recordId &&
      l.isDeleted !== true && l.isDeleted !== 'TRUE');
    requireThat(lines.length > 1 && lines.length <= 98, 409, 'REVERSAL_NOT_AVAILABLE', 'This journal cannot be reversed safely.');
    const payment = original.sourceType === `${table}Payment`;
    const kind = payment ? 'refund' : 'reversal';
    const id = challenge(`${companyId}:${operation}:${kind}`);
    changes.push({ table: 'Journals', row: journalRow++, values: {
      ...system, recordId: id, recordVersion: 1, number: `${payment ? 'REF' : 'REV'}-${id}`, date: values.date,
      description: `${payment ? 'Refund' : 'Reversal'} of ${original.recordId}: ${values.description}`,
      sourceType: payment ? `${table}Refund` : `${table}Reversal`, sourceId: record.recordId,
      totalDebit: original.totalCredit, totalCredit: original.totalDebit, status: 'POSTED',
    } });
    lines.forEach((l, index) => changes.push({ table: 'JournalLines', row: lineRow++, values: {
      ...system, recordId: challenge(`${id}:${index}`), recordVersion: 1, journalId: id, lineNumber: index + 1,
      accountId: l.accountId, accountName: l.accountName, accountGroup: l.accountGroup,
      debit: l.credit || 0, credit: l.debit || 0,
    } }));
  }
  return changes;
}
