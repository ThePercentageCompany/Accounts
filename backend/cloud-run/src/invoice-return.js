import { requireThat } from './errors.js';
import { challenge } from './crypto.js';
import { minor } from './journal-policy.js';
import { validLedgerDate, assertOpenLedgerDate } from './financial-period-policy.js';
import { invoiceLineValues } from './invoice-policy.js';

const active = row => row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = value => Number(value) / 100;
const nextRow = rows => Math.max(1, ...rows.map(r => Number(r._row) || 1)) + 1;
export function returnInput(input) {
  requireThat(input && Object.keys(input).every(k => ['date', 'reason', 'refundAccount', 'returnItems'].includes(k)) &&
    validLedgerDate(input.date) && typeof input.reason === 'string' && input.reason.trim().length >= 3 &&
    input.reason.length <= 1000 && ['', 'Cash', 'Bank'].includes(input.refundAccount ?? '') &&
    Array.isArray(input.returnItems) && input.returnItems.length > 0 && input.returnItems.length <= 100,
  400, 'INVALID_INVOICE_RETURN', 'Choose a return date, reason and at least one item.');
  const seen = new Set();
  const returnItems = input.returnItems.map(item => {
    requireThat(item && Object.keys(item).every(k => ['invoiceItemId', 'quantity'].includes(k)) &&
      typeof item.invoiceItemId === 'string' && /^[A-Za-z0-9_-]{43}$/.test(item.invoiceItemId) &&
      !seen.has(item.invoiceItemId) && minor(item.quantity) > 0n,
    400, 'INVALID_INVOICE_RETURN', 'Choose unique invoice items and positive return quantities.');
    seen.add(item.invoiceItemId);
    return { invoiceItemId: item.invoiceItemId, quantity: money(minor(item.quantity)) };
  });
  return { date: input.date, reason: input.reason.trim(), refundAccount: input.refundAccount ?? '', returnItems };
}

export async function invoiceReturnChanges(sheets, companyId, id, old, values, system, operation) {
  requireThat(old && ['ISSUED', 'PARTIALLY_PAID', 'PAID', 'PARTIALLY_RETURNED'].includes(old.status),
    409, 'INVOICE_RETURN_NOT_AVAILABLE', 'Only issued invoices with remaining items can be returned.');
  const data = await sheets.read(companyId, ['InvoiceItems', 'CreditNotes', 'CreditNoteItems', 'Journals', 'JournalLines', 'Receipts', 'ReceiptAllocations']);
  const notes = data.CreditNotes.filter(r => r.companyId === companyId && r.invoiceId === id && active(r));
  const noteIds = new Set(notes.map(n => n.recordId));
  const prior = data.CreditNoteItems.filter(r => r.companyId === companyId && noteIds.has(r.creditNoteId) && active(r));
  const lines = data.InvoiceItems.filter(r => r.companyId === companyId && r.invoiceId === id && active(r));
  const receiptIds = new Set(data.ReceiptAllocations.filter(r => r.companyId === companyId && r.invoiceId === id && active(r)).map(r => r.receiptId));
  const dates = [old.issueDate, ...notes.map(n => n.date), ...data.Receipts.filter(r => receiptIds.has(r.recordId) && active(r)).flatMap(r => [r.paymentDate, r.reversalDate || r.paymentDate])];
  requireThat(dates.every(date => values.date >= date), 400, 'INVALID_INVOICE_RETURN', 'Return date cannot precede the invoice, payments or previous returns.');
  await assertOpenLedgerDate(sheets, companyId, values.date);
  const credited = notes.reduce((sum, n) => sum + minor(n.total), 0n);
  const balance = minor(old.balance), paid = minor(old.paidAmount);
  requireThat(balance + paid + credited === minor(old.total), 409, 'INVOICE_BALANCE_INVALID', 'Invoice balances do not match its credit history.');
  const entries = values.returnItems.map((item, index) => {
    const line = lines.find(r => r.recordId === item.invoiceItemId);
    requireThat(line, 400, 'INVALID_INVOICE_RETURN', 'A returned item does not belong to this invoice.');
    const before = prior.filter(r => r.invoiceItemId === line.recordId).reduce((sum, r) => sum + minor(r.quantity), 0n);
    const qty = minor(line.quantity), after = before + minor(item.quantity);
    requireThat(after <= qty, 409, 'RETURN_QUANTITY_EXCEEDED', 'Return quantity exceeds the remaining invoiced quantity.');
    const original = invoiceLineValues({ ...line, lineNumber: Number(line.lineNumber) });
    // Cumulative proportional rounding guarantees repeated partial returns
    // sum exactly to the original gross, discount and VAT when fully returned.
    const portion = amount => (amount * after + qty / 2n) / qty - (amount * before + qty / 2n) / qty;
    const discount = portion(original.discount), tax = portion(original.tax);
    const gross = portion(original.gross - original.discount) + discount;
    return { invoiceItemId: line.recordId, invoiceId: id, lineNumber: index + 1,
      description: line.description, quantity: item.quantity, unitPrice: line.unitPrice, taxRate: line.taxRate || 0,
      subtotal: money(gross), discount: money(discount), taxAmount: money(tax), lineTotal: money(gross - discount + tax) };
  });
  const sum = key => entries.reduce((value, e) => value + minor(e[key]), 0n);
  const total = sum('lineTotal'), tax = sum('taxAmount');
  const applied = total < balance ? total : balance, refund = total - applied;
  requireThat(refund <= paid && (refund === 0n || ['Cash', 'Bank'].includes(values.refundAccount)),
    400, 'RETURN_REFUND_ACCOUNT_REQUIRED', 'Choose Cash or Bank for the customer refund.');
  const year = values.date.slice(0, 4), pattern = new RegExp(`^CN-${year}-(\\d{6})$`);
  const sequence = Math.max(0, ...data.CreditNotes.filter(n => n.companyId === companyId).map(n => Number(pattern.exec(n.number)?.[1]) || 0)) + 1;
  requireThat(sequence <= 999999, 409, 'CREDIT_SEQUENCE_EXHAUSTED', 'Credit note numbering is exhausted.');
  const number = `CN-${year}-${String(sequence).padStart(6, '0')}`;
  const noteId = challenge(`${companyId}:${operation}:credit-note`), journalId = challenge(`${companyId}:${operation}:return-journal`);
  const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
  const fullyReturned = lines.every(line => {
    const previous = prior.filter(r => r.invoiceItemId === line.recordId).reduce((sum, r) => sum + minor(r.quantity), 0n);
    const current = entries.filter(r => r.invoiceItemId === line.recordId).reduce((sum, r) => sum + minor(r.quantity), 0n);
    return previous + current === minor(line.quantity);
  });
  const ledger = [
    { accountId: 'service_consulting_revenue', accountName: 'Service & Consulting Revenue', accountGroup: 'Income', debit: money(total - tax), credit: 0 },
    { accountId: 'output_vat_payable', accountName: 'Output VAT Payable', accountGroup: 'Liability', debit: money(tax), credit: 0 },
    { accountId: 'accounts_receivable', accountName: 'Accounts Receivable', accountGroup: 'Asset', debit: 0, credit: money(applied) },
    { accountId: values.refundAccount === 'Cash' ? 'cash' : 'bank', accountName: values.refundAccount, accountGroup: 'Asset', debit: 0, credit: money(refund) },
  ].filter(e => e.debit || e.credit);
  return { values: { balance: money(balance - applied), paidAmount: money(paid - refund), status: fullyReturned ? 'RETURNED' : 'PARTIALLY_RETURNED' }, extra: [
    { table: 'CreditNotes', row: nextRow(data.CreditNotes), values: { ...meta, recordId: noteId, number, invoiceId: id,
      customerId: old.customerId, date: values.date, reason: values.reason, currency: old.currency, subtotal: money(sum('subtotal')),
      discount: money(sum('discount')), taxAmount: money(tax), total: money(total), refundAmount: money(refund),
      refundAccount: refund > 0n ? values.refundAccount : '', status: 'POSTED' } },
    ...entries.map((entry, i) => ({ table: 'CreditNoteItems', row: nextRow(data.CreditNoteItems) + i,
      values: { ...meta, recordId: challenge(`${noteId}:${i}`), creditNoteId: noteId, ...entry } })),
    ...(total > 0n ? [
      { table: 'Journals', row: nextRow(data.Journals), values: { ...meta, recordId: journalId, number,
        date: values.date, description: `Credit note ${number} for ${old.number}: ${values.reason}`,
        sourceType: 'InvoiceReturn', sourceId: id, totalDebit: money(total), totalCredit: money(total), status: 'POSTED' } },
      ...ledger.map((entry, i) => ({ table: 'JournalLines', row: nextRow(data.JournalLines) + i,
        values: { ...meta, recordId: challenge(`${journalId}:${i}`), journalId, lineNumber: i + 1, ...entry } })),
    ] : []),
  ] };
}
