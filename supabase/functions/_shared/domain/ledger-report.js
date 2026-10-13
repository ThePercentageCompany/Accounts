import { requireThat } from './errors.js';
import { minor, lineAmounts } from './journal-policy.js';
import { validLedgerDate } from './financial-period-policy.js';

const active = row => row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = value => value < 0n ? `-${money(-value)}` : `${value / 100n}.${String(value % 100n).padStart(2, '0')}`;
export function trialBalance(companyId, asOf, data, from = null) {
  requireThat(validLedgerDate(asOf), 400, 'INVALID_REPORT_DATE', 'Supply a valid asOf date.');
  requireThat(from === null || (validLedgerDate(from) && from <= asOf), 400, 'INVALID_REPORT_DATE', 'Supply an ordered report period.');
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
    if (journal.date > asOf || (from !== null && journal.date < from)) continue;
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

export function profitAndLoss(companyId, from, asOf, data) {
  requireThat(validLedgerDate(from), 400, 'INVALID_REPORT_DATE', 'Supply a valid from date.');
  const trial = trialBalance(companyId, asOf, data, from);
  let income = 0n, expenses = 0n;
  const accounts = trial.accounts.filter(a => ['Income', 'Expense'].includes(a.accountGroup)).map(a => {
    const debit = BigInt(a.debit.replace('.', '')), credit = BigInt(a.credit.replace('.', ''));
    const amount = a.accountGroup === 'Income' ? credit - debit : debit - credit;
    if (a.accountGroup === 'Income') income += amount; else expenses += amount;
    return { accountId: a.accountId, accountName: a.accountName, accountGroup: a.accountGroup, amount: money(amount) };
  });
  return { from, asOf, journalCount: trial.journalCount, accounts,
    totalIncome: money(income), totalExpenses: money(expenses), netProfit: money(income - expenses) };
}

export function balanceSheet(companyId, asOf, data) {
  const trial = trialBalance(companyId, asOf, data);
  let assets = 0n, liabilities = 0n, equity = 0n, earnings = 0n;
  const accounts = [];
  for (const account of trial.accounts) {
    const net = BigInt(account.debit.replace('.', '')) - BigInt(account.credit.replace('.', ''));
    if (['Income', 'Expense'].includes(account.accountGroup)) { earnings -= net; continue; }
    const amount = account.accountGroup === 'Asset' ? net : -net;
    if (account.accountGroup === 'Asset') assets += amount;
    else if (account.accountGroup === 'Liability') liabilities += amount;
    else equity += amount;
    accounts.push({ accountId: account.accountId, accountName: account.accountName,
      accountGroup: account.accountGroup, amount: money(amount) });
  }
  const totalEquity = equity + earnings;
  requireThat(assets === liabilities + totalEquity, 409, 'LEDGER_INTEGRITY', 'The balance sheet does not reconcile.');
  return { asOf, journalCount: trial.journalCount, accounts, totalAssets: money(assets),
    totalLiabilities: money(liabilities), postedEquity: money(equity), accumulatedEarnings: money(earnings),
    totalEquity: money(totalEquity), totalLiabilitiesAndEquity: money(liabilities + totalEquity), balanced: true };
}

export function dashboard(companyId, from, asOf, data) {
  const profit = profitAndLoss(companyId, from, asOf, data);
  const balance = balanceSheet(companyId, asOf, data);
  const amount = id => balance.accounts.find(a => a.accountId === id)?.amount ?? '0.00';
  return { from, asOf, journalCount: balance.journalCount, totalIncome: profit.totalIncome,
    totalExpenses: profit.totalExpenses, netProfit: profit.netProfit, totalAssets: balance.totalAssets,
    totalLiabilities: balance.totalLiabilities, totalEquity: balance.totalEquity,
    cash: amount('cash_in_hand'), bank: amount('bank_account'), receivables: amount('accounts_receivable'),
    payables: amount('accounts_payable'), balanced: balance.balanced };
}

// Validate the full ledger through the cutoff before exposing any detail.
// Balances use debit-positive signs, including liability and income accounts.
export function generalLedger(companyId, from, asOf, data) {
  requireThat(validLedgerDate(from) && from <= asOf, 400, 'INVALID_REPORT_DATE', 'Supply an ordered report period.');
  const trial = trialBalance(companyId, asOf, data);
  const journals = new Map(data.Journals.filter(j => j.companyId === companyId && active(j) &&
    j.status === 'POSTED' && j.date <= asOf).map(j => [j.recordId, j]));
  const lines = data.JournalLines.filter(l => l.companyId === companyId && active(l) && journals.has(l.journalId))
    .sort((a, b) => journals.get(a.journalId).date.localeCompare(journals.get(b.journalId).date) ||
      a.journalId.localeCompare(b.journalId) || a.lineNumber - b.lineNumber);
  const accounts = trial.accounts.map(account => {
    let opening = 0n, balance = 0n, debit = 0n, credit = 0n;
    const entries = [];
    for (const line of lines.filter(l => l.accountId === account.accountId)) {
      const journal = journals.get(line.journalId), amount = lineAmounts(line);
      balance += amount.debit - amount.credit;
      if (journal.date < from) { opening = balance; continue; }
      debit += amount.debit; credit += amount.credit;
      entries.push({ date: journal.date, journalId: journal.recordId, number: journal.number || '',
        description: journal.description || '', sourceType: journal.sourceType || '', sourceId: journal.sourceId || '', lineNumber: line.lineNumber,
        debit: money(amount.debit), credit: money(amount.credit), balance: money(balance) });
    }
    return { accountId: account.accountId, accountName: account.accountName, accountGroup: account.accountGroup,
      opening: money(opening), debit: money(debit), credit: money(credit), closing: money(balance), entries };
  });
  return { from, asOf, journalCount: [...journals.values()].filter(j => j.date >= from).length, accounts };
}
