import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = cents => Number(cents) / 100;
const nextRow = rows => Math.max(1, ...rows.map(row => Number(row._row) || 1)) + 1;

export function receiptInput(input) {
  requireThat(input && typeof input === 'object' && !Array.isArray(input) &&
    Object.keys(input).length > 0 && Object.keys(input).every(key =>
      ['invoiceId', 'customerId', 'paymentDate', 'amount', 'currency', 'paymentAccount', 'reference'].includes(key)),
  400, 'INVALID_RECEIPT', 'Supply one invoice and its payment details.');
  const values = { ...input, reference: input.reference ?? '' };
  requireThat(typeof values.invoiceId === 'string' && /^[A-Za-z0-9_-]{43}$/.test(values.invoiceId) &&
    typeof values.customerId === 'string' && /^[A-Za-z0-9_-]{43}$/.test(values.customerId) &&
    validLedgerDate(values.paymentDate) && typeof values.currency === 'string' && /^[A-Z]{3}$/.test(values.currency) &&
    ['Cash', 'Bank'].includes(values.paymentAccount) && typeof values.reference === 'string' && values.reference.length <= 500,
  400, 'INVALID_RECEIPT', 'Choose an invoice, date, currency and Cash or Bank account.');
  requireThat(minor(values.amount) > 0n, 400, 'INVALID_RECEIPT', 'Receipt amount must be positive.');
  return Object.fromEntries(Object.keys(values).sort().map(key => [key, values[key]]));
}

export async function receiptChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (table === 'ReceiptAllocations') {
    requireThat(false, 409, 'RECEIPT_LOCKED', 'Receipt allocations are created by the payment workflow.');
  }
  if (table !== 'Receipts') return { values, extra: [] };
  requireThat((action === 'receive' && !old) || action === 'receiptReverse', 409, 'RECEIPT_LOCKED', 'Posted receipts cannot be edited or deleted.');
  if (action === 'receiptReverse') {
    requireThat(old?.status === 'POSTED' && Object.keys(values).every(key => ['reversalDate', 'reversalReason'].includes(key)) &&
      validLedgerDate(values.reversalDate) && values.reversalDate >= old.paymentDate && typeof values.reversalReason === 'string' &&
      values.reversalReason.trim().length > 0 && values.reversalReason.length <= 500,
    409, 'RECEIPT_NOT_REVERSIBLE', 'Choose a valid reversal date and reason for a posted receipt.');
    await assertOpenLedgerDate(sheets, companyId, values.reversalDate);
    const data = await sheets.read(companyId, ['Invoices', 'Receipts', 'ReceiptAllocations', 'Journals', 'JournalLines', 'CreditNotes']);
    const allocation = data.ReceiptAllocations.filter(row => row.companyId === companyId && row.receiptId === id && active(row));
    requireThat(allocation.length === 1, 409, 'RECEIPT_NOT_REVERSIBLE', 'Receipt allocation is missing or inconsistent.');
    const invoice = data.Invoices.find(row => row.companyId === companyId && row.recordId === allocation[0].invoiceId && active(row));
    const credits = data.CreditNotes.filter(n => n.companyId === companyId && n.invoiceId === invoice?.recordId && active(n));
    requireThat(credits.every(n => values.reversalDate >= n.date), 409, 'RECEIPT_NOT_REVERSIBLE', 'Receipt reversal date cannot precede a credit note.');
    requireThat(credits.every(n => minor(n.refundAmount || 0) === 0n), 409, 'RECEIPT_NOT_REVERSIBLE', 'This invoice has customer refunds. Its original receipts cannot be reversed.');
    const amount = minor(old.amount), paid = minor(invoice?.paidAmount ?? 0), balance = minor(invoice?.balance ?? 0), total = minor(invoice?.total ?? 0) - credits.reduce((sum, n) => sum + minor(n.total), 0n);
    requireThat(invoice && paid >= amount && paid + balance === total && ['PAID', 'PARTIALLY_PAID', 'PARTIALLY_RETURNED'].includes(invoice.status),
      409, 'RECEIPT_NOT_REVERSIBLE', 'Invoice payment totals are inconsistent.');
    const original = data.Journals.filter(row => row.companyId === companyId && row.sourceType === 'Receipt' && row.sourceId === id && active(row));
    const previous = data.Journals.some(row => row.companyId === companyId && row.sourceType === 'ReceiptReversal' && row.sourceId === id && active(row));
    requireThat(original.length === 1 && original[0].status === 'POSTED' && !previous,
      409, 'RECEIPT_NOT_REVERSIBLE', 'Receipt journal is missing, duplicated or already reversed.');
    const newPaid = paid - amount, newBalance = balance + amount, journalId = challenge(`${companyId}:${operation}:receipt-reversal`);
    const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    const accountId = old.paymentAccount === 'Cash' ? 'cash' : 'bank';
    return { values: { status: 'REVERSED', reversalDate: values.reversalDate, reversalReason: values.reversalReason.trim() }, extra: [
      { table: 'Invoices', row: invoice._row, values: { paidAmount: money(newPaid), balance: money(newBalance),
        status: credits.length ? 'PARTIALLY_RETURNED' : newPaid === 0n ? 'ISSUED' : 'PARTIALLY_PAID', updatedAt: system.updatedAt, updatedBy: system.updatedBy,
        recordVersion: Number(invoice.recordVersion) + 1, syncStatus: 'SYNCED', idempotencyKey: system.idempotencyKey } },
      { table: 'Journals', row: nextRow(data.Journals), values: { ...meta, recordId: journalId, number: `AUTO-${journalId}`,
        date: values.reversalDate, description: `Reverse ${old.number}: ${values.reversalReason.trim()}`,
        sourceType: 'ReceiptReversal', sourceId: id, totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED' } },
      { table: 'JournalLines', row: nextRow(data.JournalLines), values: { ...meta, recordId: challenge(`${journalId}:0`),
        journalId, lineNumber: 1, accountId: 'accounts_receivable', accountName: 'Accounts Receivable', accountGroup: 'Asset', debit: money(amount), credit: 0 } },
      { table: 'JournalLines', row: nextRow(data.JournalLines) + 1, values: { ...meta, recordId: challenge(`${journalId}:1`),
        journalId, lineNumber: 2, accountId, accountName: old.paymentAccount, accountGroup: 'Asset', debit: 0, credit: money(amount) } },
    ] };
  }
  const { invoiceId, ...receipt } = values;
  const data = await sheets.read(companyId, ['Customers', 'Invoices', 'Receipts', 'ReceiptAllocations', 'Journals', 'JournalLines', 'CreditNotes']);
  const customer = data.Customers.find(row => row.companyId === companyId && row.recordId === receipt.customerId && active(row));
  const invoice = data.Invoices.find(row => row.companyId === companyId && row.recordId === invoiceId && active(row));
  requireThat(customer, 409, 'RECEIPT_CUSTOMER_INVALID', 'The selected customer is unavailable.');
  requireThat(invoice && ['ISSUED', 'PARTIALLY_PAID', 'PARTIALLY_RETURNED'].includes(invoice.status), 409, 'INVOICE_NOT_PAYABLE', 'The selected invoice is not open for payment.');
  requireThat(invoice.customerId === receipt.customerId, 409, 'RECEIPT_CUSTOMER_MISMATCH', 'The receipt customer does not match the invoice.');
  requireThat(invoice.currency === receipt.currency, 409, 'RECEIPT_CURRENCY_MISMATCH', 'The receipt currency does not match the invoice.');
  requireThat(receipt.paymentDate >= invoice.issueDate, 409, 'INVALID_PAYMENT_DATE', 'Payment date cannot precede the invoice date.');
  await assertOpenLedgerDate(sheets, companyId, receipt.paymentDate);
  const credits = data.CreditNotes.filter(n => n.companyId === companyId && n.invoiceId === invoiceId && active(n));
  requireThat(credits.every(n => receipt.paymentDate >= n.date), 409, 'INVALID_PAYMENT_DATE', 'Payment date cannot precede a credit note.');
  const total = minor(invoice.total) - credits.reduce((sum, n) => sum + minor(n.total), 0n), paid = minor(invoice.paidAmount ?? 0), balance = minor(invoice.balance);
  requireThat(paid + balance === total && balance > 0n, 409, 'INVOICE_BALANCE_INVALID', 'Refresh or repair the invoice balance before receiving payment.');
  const amount = minor(receipt.amount);
  requireThat(amount <= balance, 409, 'RECEIPT_OVERPAYMENT', 'Receipt amount exceeds the invoice balance.');

  const year = receipt.paymentDate.slice(0, 4), pattern = new RegExp(`^REC-${year}-(\\d{6})$`);
  const sequence = Math.max(0, ...data.Receipts.filter(row => row.companyId === companyId && active(row))
    .map(row => pattern.exec(row.number)?.[1]).filter(Boolean).map(Number)) + 1;
  requireThat(sequence <= 999999, 409, 'RECEIPT_SEQUENCE_EXHAUSTED', 'Receipt numbering is exhausted for this year.');
  const number = `REC-${year}-${String(sequence).padStart(6, '0')}`;
  const allocationId = challenge(`${companyId}:${operation}:receipt-allocation`);
  const journalId = challenge(`${companyId}:${operation}:receipt-journal`);
  const journalSystem = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
  const newPaid = paid + amount, newBalance = balance - amount;
  const accountId = receipt.paymentAccount === 'Cash' ? 'cash' : 'bank';
  const accountName = receipt.paymentAccount === 'Cash' ? 'Cash' : 'Bank';
  return { values: { ...receipt, number, status: 'POSTED', reversalDate: '', reversalReason: '' }, extra: [
    { table: 'ReceiptAllocations', row: nextRow(data.ReceiptAllocations), values: {
      ...journalSystem, recordId: allocationId, receiptId: id, invoiceId, amount: money(amount),
    } },
    { table: 'Invoices', row: invoice._row, values: {
      paidAmount: money(newPaid), balance: money(newBalance), status: credits.length ? 'PARTIALLY_RETURNED' : newBalance === 0n ? 'PAID' : 'PARTIALLY_PAID',
      updatedAt: system.updatedAt, updatedBy: system.updatedBy, recordVersion: Number(invoice.recordVersion) + 1,
      syncStatus: 'SYNCED', idempotencyKey: system.idempotencyKey,
    } },
    { table: 'Journals', row: nextRow(data.Journals), values: {
      ...journalSystem, recordId: journalId, number: `AUTO-${journalId}`, date: receipt.paymentDate,
      description: `Receipt ${number}`, sourceType: 'Receipt', sourceId: id,
      totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED',
    } },
    { table: 'JournalLines', row: nextRow(data.JournalLines), values: {
      ...journalSystem, recordId: challenge(`${journalId}:0`), journalId, lineNumber: 1,
      accountId, accountName, accountGroup: 'Asset', debit: money(amount), credit: 0,
    } },
    { table: 'JournalLines', row: nextRow(data.JournalLines) + 1, values: {
      ...journalSystem, recordId: challenge(`${journalId}:1`), journalId, lineNumber: 2,
      accountId: 'accounts_receivable', accountName: 'Accounts Receivable', accountGroup: 'Asset', debit: 0, credit: money(amount),
    } },
  ] };
}
