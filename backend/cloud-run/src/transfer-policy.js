import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { minor } from './journal-policy.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';

const accounts = { cash: ['cash_in_hand', 'Cash in Hand'], bank: ['bank_account', 'Bank Account'] };
const nextRow = rows => Math.max(1, ...rows.map(r => Number(r._row) || 1)) + 1;
export async function transferChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (table !== 'MoneyTransfers') return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'transferPost', 'transferReverse', 'transferMatch'].includes(action), 400, 'INVALID_TRANSFER', 'Unsupported transfer action.');
  if (['create', 'update', 'delete'].includes(action)) {
    requireThat(!old || old.status === 'DRAFT', 409, 'TRANSFER_LOCKED', 'Posted transfers must be reversed rather than edited or deleted.');
    if (action === 'delete') return { values, extra: [] };
    requireThat(Object.keys(values).every(k => ['date', 'fromAccount', 'toAccount', 'amount', 'reference', 'description'].includes(k)), 400, 'INVALID_TRANSFER', 'Status and matching details are assigned by the server.');
    const next = { ...old, ...values };
    requireThat(validLedgerDate(next.date) && Object.hasOwn(accounts, next.fromAccount) && Object.hasOwn(accounts, next.toAccount) && next.fromAccount !== next.toAccount &&
      minor(next.amount) > 0n && typeof next.description === 'string' && next.description.trim().length > 0 && next.description.length <= 500 &&
      typeof (next.reference ?? '') === 'string' && (next.reference ?? '').length <= 500,
    400, 'INVALID_TRANSFER', 'Supply a valid date, positive amount, description and different Cash/Bank accounts.');
    return { values: { ...values, description: next.description.trim(), status: 'DRAFT', bankStatus: 'PENDING', statementDate: '', statementReference: '', reversalDate: '', reversalReason: '' }, extra: [] };
  }
  if (action === 'transferMatch') {
    requireThat(old?.status === 'POSTED' && Object.keys(values).every(k => ['bankStatus', 'statementDate', 'statementReference'].includes(k)) &&
      ['PENDING', 'CLEARED'].includes(values.bankStatus) && (values.bankStatus === 'PENDING' ||
        (validLedgerDate(values.statementDate) && values.statementDate >= old.date && typeof values.statementReference === 'string' && values.statementReference.trim().length > 0 && values.statementReference.length <= 500)),
    400, 'INVALID_TRANSFER_MATCH', 'Match a posted transfer using the statement date and reference.');
    return { values: values.bankStatus === 'PENDING' ? { bankStatus: 'PENDING', statementDate: '', statementReference: '' } : values, extra: [] };
  }
  const reversal = action === 'transferReverse';
  requireThat(old?.status === (reversal ? 'POSTED' : 'DRAFT'), 409, 'TRANSFER_NOT_POSTABLE', 'Transfer is not eligible for this action.');
  requireThat(reversal ? Object.keys(values).every(k => ['reversalDate', 'reversalReason'].includes(k)) &&
    validLedgerDate(values.reversalDate) && values.reversalDate >= old.date && typeof values.reversalReason === 'string' &&
    values.reversalReason.trim().length > 0 && values.reversalReason.length <= 500 : Object.keys(values).length === 0,
  400, 'INVALID_TRANSFER', 'Supply a valid reversal date and reason.');
  const date = reversal ? values.reversalDate : old.date;
  await assertOpenLedgerDate(sheets, companyId, date);
  const amount = Number(minor(old.amount)) / 100;
  requireThat(amount > 0 && Object.hasOwn(accounts, old.fromAccount) && Object.hasOwn(accounts, old.toAccount) && old.fromAccount !== old.toAccount, 409, 'INVALID_TRANSFER', 'Correct the transfer accounts and amount.');
  const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
  const journalId = challenge(`${companyId}:${operation}:transfer`);
  const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
  const destination = accounts[reversal ? old.fromAccount : old.toAccount];
  const source = accounts[reversal ? old.toAccount : old.fromAccount];
  return { values: reversal ? { ...values, status: 'REVERSED' } : { status: 'POSTED' }, extra: [
    { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: journalId, number: `AUTO-${journalId}`, date,
      description: reversal ? `Transfer reversal: ${values.reversalReason}` : old.description,
      sourceType: reversal ? 'MoneyTransferReversal' : 'MoneyTransfer', sourceId: id, totalDebit: amount, totalCredit: amount, status: 'POSTED' } },
    ...[destination, source].map(([accountId, accountName], index) => ({ table: 'JournalLines', row: nextRow(ledger.JournalLines) + index,
      values: { ...meta, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1, accountId, accountName,
        accountGroup: 'Asset', debit: index === 0 ? amount : 0, credit: index === 1 ? amount : 0 } })),
  ] };
}
