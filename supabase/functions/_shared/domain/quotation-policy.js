import { challenge } from './crypto.js';
import { replaceDraftItems } from './document-draft.js';
import { nextDocumentNumber } from './document-number.js';
import { requireThat } from './errors.js';
import { validLedgerDate } from './financial-period-policy.js';
import { invoiceLineValues, invoicePrefix, cashCustomerName } from './invoice-policy.js';
import { minor } from './journal-policy.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = cents => Number(cents) / 100;
const nextRow = rows => Math.max(1, ...rows.map(row => Number(row._row) || 1)) + 1;
function quotationPrefix(profile) {
  const prefix = String(profile?.quotationPrefix || 'QUO').trim().toUpperCase();
  requireThat(/^[A-Z0-9-]{1,12}$/.test(prefix), 409, 'INVALID_QUOTATION_PREFIX', 'Configure a valid quotation prefix.');
  return prefix;
}
function totals(lines) {
  let subtotal = 0n, discount = 0n, tax = 0n, total = 0n;
  const numbers = new Set();
  for (const line of lines) {
    requireThat(!numbers.has(line.lineNumber), 409, 'INVALID_QUOTATION_LINE', 'Quotation line numbers must be unique.');
    numbers.add(line.lineNumber);
    const value = invoiceLineValues(line);
    subtotal += value.gross; discount += value.discount; tax += value.tax; total += value.total;
  }
  return { subtotal: money(subtotal), discount: money(discount), taxAmount: money(tax), total: money(total) };
}

export async function quotationChanges(records, companyId, table, id, action, old, values, system, operation) {
  if (!['Quotations', 'QuotationItems'].includes(table)) return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'send', 'convert'].includes(action), 400, 'INVALID_QUOTATION', 'Unsupported quotation action.');
  if (table === 'Quotations') {
    requireThat(!old || old.status === 'DRAFT' || action === 'convert' && old.status === 'SENT',
      409, 'QUOTATION_LOCKED', 'Only draft quotations can be edited.');
    if (['send', 'convert'].includes(action)) {
      const names = ['Quotations', 'QuotationItems', 'CompanyProfile', 'Invoices', 'InvoiceItems'];
      const data = await records.read(companyId, names);
      const lines = data.QuotationItems.filter(line => line.companyId === companyId && line.quotationId === id && active(line));
      requireThat(lines.length > 0, 409, 'QUOTATION_EMPTY', 'Add at least one quotation line first.');
      const calculated = totals(lines);
      requireThat(old && old.subtotal === calculated.subtotal && old.discount === calculated.discount &&
        old.taxAmount === calculated.taxAmount && old.total === calculated.total,
      409, 'QUOTATION_TOTAL_MISMATCH', 'Refresh or repair quotation totals first.');
      if (action === 'send') {
        // Sent quotations keep the number assigned when the draft was created;
        // only legacy drafts saved before create-time numbering are numbered here.
        const profile = data.CompanyProfile.find(row => row.companyId === companyId && active(row));
        const number = old.number || await nextDocumentNumber(records, companyId, 'Quotations', quotationPrefix(profile), old.issueDate,
          'QUOTATION_SEQUENCE_EXHAUSTED', 'Quotation numbering is exhausted for this year.');
        return { values: { ...calculated, number, status: 'SENT' }, extra: [] };
      }
      requireThat(old.status === 'SENT' && !old.convertedInvoiceId, 409, 'QUOTATION_NOT_CONVERTIBLE', 'Only an unconverted sent quotation can become an invoice.');
      const invoiceId = challenge(`${companyId}:${operation}:quotation-invoice`);
      const invoiceNumber = await nextDocumentNumber(records, companyId, 'Invoices',
        invoicePrefix(data.CompanyProfile.find(row => row.companyId === companyId && active(row))), old.issueDate,
        'INVOICE_SEQUENCE_EXHAUSTED', 'Invoice numbering is exhausted for this year.');
      const invoiceSystem = { ...system, recordId: invoiceId, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
      return { values: { status: 'CONVERTED', convertedInvoiceId: invoiceId }, extra: [
        { table: 'Invoices', row: nextRow(data.Invoices), values: { ...invoiceSystem, number: invoiceNumber,
          customerId: old.customerId, cashCustomerName: old.cashCustomerName || '',
          issueDate: old.issueDate, dueDate: '', status: 'DRAFT', currency: old.currency, baseCurrency: old.baseCurrency || old.currency, exchangeRate: old.exchangeRate || 1, rateDate: old.rateDate || old.issueDate, rateSource: old.rateSource || 'LEGACY', ...calculated,
          paidAmount: 0, balance: calculated.total, notes: old.notes || '', paymentTerms: old.paymentTerms || '', documentId: '' } },
        ...lines.map((line, index) => ({ table: 'InvoiceItems', row: nextRow(data.InvoiceItems) + index, values: {
          ...invoiceSystem, recordId: challenge(`${invoiceId}:line:${index}`), invoiceId, lineNumber: line.lineNumber,
          productId: line.productId || '', description: line.description, quantity: line.quantity, unitPrice: line.unitPrice,
          discount: line.discount || 0, taxRate: line.taxRate || 0, taxAmount: line.taxAmount, lineTotal: line.lineTotal,
        } })),
      ] };
    }
    if (action === 'delete') return { values, extra: [] };
    requireThat(!Object.keys(values).some(key => ['number', 'subtotal', 'discount', 'taxAmount', 'total', 'convertedInvoiceId'].includes(key)),
      400, 'QUOTATION_DERIVED_FIELD', 'Quotation totals and numbering are assigned by the server.');
    const record = { ...old, ...values, status: values.status ?? old?.status ?? 'DRAFT' };
    requireThat(record.status === 'DRAFT' && typeof record.customerId === 'string' && validLedgerDate(record.issueDate) &&
      validLedgerDate(record.validUntil) && record.validUntil >= record.issueDate && /^[A-Z]{3}$/.test(record.currency),
    400, 'INVALID_QUOTATION', 'Choose a customer, currency and valid quotation dates.');
    const cashName = cashCustomerName(record);
    const data = await records.read(companyId, old ? ['QuotationItems'] : ['CompanyProfile', 'Quotations', 'QuotationItems']);
    const { items, ...header } = values;
    const lines = data.QuotationItems.filter(line => line.companyId === companyId && line.quotationId === id && active(line));
    const replacement = items === undefined ? { lines, extra: [] } :
      replaceDraftItems(companyId, 'QuotationItems', 'quotationId', id, data.QuotationItems,
        items, system, operation, invoiceLineValues);
    // Every draft receives its document number immediately so lists, exports and
    // PDFs can reference it; sending and later steps keep it unchanged.
    const number = old ? undefined : await nextDocumentNumber(records, companyId, 'Quotations',
      quotationPrefix(data.CompanyProfile.find(row => row.companyId === companyId && active(row))), record.issueDate,
      'QUOTATION_SEQUENCE_EXHAUSTED', 'Quotation numbering is exhausted for this year.');
    return { values: { ...header, cashCustomerName: cashName, ...(number ? { number } : {}), status: 'DRAFT', ...totals(replacement.lines) }, extra: replacement.extra };
  }
  const next = { ...old, ...values };
  requireThat(!old || old.quotationId === next.quotationId, 409, 'QUOTATION_LOCKED', 'Moving quotation lines is not supported.');
  const data = await records.read(companyId, ['Quotations', 'QuotationItems']);
  const parent = data.Quotations.find(row => row.companyId === companyId && row.recordId === next.quotationId && active(row));
  requireThat(parent?.status === 'DRAFT', 409, 'QUOTATION_LOCKED', 'Only draft quotation lines can change.');
  let write = values;
  if (action !== 'delete') {
    const amount = invoiceLineValues(next);
    requireThat(!Object.hasOwn(values, 'taxAmount') || minor(values.taxAmount) === amount.tax,
      400, 'QUOTATION_TOTAL_MISMATCH', 'Line totals do not match calculated amounts.');
    requireThat(!Object.hasOwn(values, 'lineTotal') || minor(values.lineTotal) === amount.total,
      400, 'QUOTATION_TOTAL_MISMATCH', 'Line totals do not match calculated amounts.');
    write = { ...values, discount: next.discount ?? 0, taxRate: next.taxRate ?? 0, taxAmount: money(amount.tax), lineTotal: money(amount.total) };
  }
  const lines = data.QuotationItems.filter(line => line.companyId === companyId && line.quotationId === parent.recordId && line.recordId !== id && active(line));
  if (action !== 'delete') lines.push({ ...next, ...write });
  return { values: write, extra: [{ table: 'Quotations', row: parent._row, values: { ...totals(lines),
    updatedAt: system.updatedAt, updatedBy: system.updatedBy, recordVersion: Number(parent.recordVersion) + 1,
    syncStatus: 'SYNCED', idempotencyKey: system.idempotencyKey } }] };
}
