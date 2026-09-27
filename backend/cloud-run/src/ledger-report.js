import { requireThat } from './errors.js';
import { minor, lineAmounts } from './journal-policy.js';
import { validLedgerDate } from './financial-period-policy.js';

const active = row => row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = value => `${value / 100n}.${String(value % 100n).padStart(2, '0')}`;
export function trialBalance(companyId, asOf, data) {
  requireThat(validLedgerDate(asOf), 400, 'INVALID_REPORT_DATE', 'Supply a valid asOf date.');
  const journals = data.Journals.filter(j => j.companyId === companyId && active(j) && j.status === 'POSTED');
  const accounts = new Map(), seen = new Set();
  const linesByJournal = new Map();
  for (const line of data.JournalLines.filter(l => l.companyId === companyId && active(l))) {
    const lines = linesByJournal.get(line.journalId) || [];
    lines.push(line); linesByJournal.set(line.journalId, lines);
  }
  let count = 0;
  for (const journal of journals) {
    requireThat(validLedgerDate(journal.date) && !seen.has(journal.recordId), 409, 'LEDGER_INTEGRITY', 'Posted journal identity or date is invalid.');
    seen.add(journal.recordId);
    if (journal.date > asOf) continue;
    const lines = linesByJournal.get(journal.recordId) || [];
    requireThat(lines.length >= 2, 409, 'LEDGER_INTEGRITY', 'A posted journal has missing lines.');
    let debit = 0n, credit = 0n;
    const numbers = new Set();
    for (const line of lines) {
      const amount = lineAmounts(line);
      requireThat(!numbers.has(line.lineNumber) && typeof line.accountName === 'string' && line.accountName.trim() &&
        ['Asset', 'Liability', 'Equity', 'Income', 'Expense'].includes(line.accountGroup),
      409, 'LEDGER_INTEGRITY', 'Posted account classification or line numbers are inconsistent.');
      numbers.add(line.lineNumber); debit += amount.debit; credit += amount.credit;
      const account = accounts.get(line.accountId) || { accountId: line.accountId, accountName: line.accountName, accountGroup: line.accountGroup, balance: 0n };
      requireThat(account.accountGroup === line.accountGroup && account.accountName === line.accountName,
        409, 'LEDGER_INTEGRITY', 'An account has conflicting names or classifications.');
      account.balance += amount.debit - amount.credit;
      accounts.set(line.accountId, account);
    }
    requireThat(debit > 0n && debit === credit && minor(journal.totalDebit) === debit && minor(journal.totalCredit) === credit,
      409, 'LEDGER_INTEGRITY', 'Posted journal totals do not match balanced lines.');
    count++;
  }
  let debit = 0n, credit = 0n;
  const rows = [...accounts.values()].sort((a, b) => a.accountId.localeCompare(b.accountId)).map(a => {
    const dr = a.balance > 0n ? a.balance : 0n, cr = a.balance < 0n ? -a.balance : 0n;
    debit += dr; credit += cr;
    return { accountId: a.accountId, accountName: a.accountName, accountGroup: a.accountGroup, debit: money(dr), credit: money(cr) };
  });
  return { asOf, journalCount: count, accounts: rows, totalDebit: money(debit), totalCredit: money(credit), balanced: debit === credit };
}
