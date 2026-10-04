import { requireThat } from './errors.js';
import { minor } from './journal-policy.js';
import { validLedgerDate } from './financial-period-policy.js';
import { assertOpenLedgerDate } from './financial-period-policy.js';
import { challenge } from './crypto.js';
import { replaceDraftItems } from './document-draft.js';
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const dollars = cents => Number(cents) / 100;

export function invoiceLineValues(record) {
  const quantity = minor(record.quantity), price = minor(record.unitPrice), discount = minor(record.discount ?? 0), rate = minor(record.taxRate ?? 0);
  requireThat(quantity > 0n && rate <= 10000n && Number.isSafeInteger(record.lineNumber) && record.lineNumber > 0 &&
    typeof record.description === 'string' && record.description.trim(), 400, 'INVALID_INVOICE_LINE', 'Enter a description, positive quantity and line number, and a tax rate from 0 to 100.');
  const gross = (quantity * price + 50n) / 100n;
  requireThat(discount <= gross, 400, 'INVALID_INVOICE_LINE', 'Line discount exceeds its amount.');
  const tax = ((gross - discount) * rate + 5000n) / 10000n;
  requireThat(gross + tax <= 100000000000000n, 400, 'INVALID_INVOICE_LINE', 'Line exceeds the supported amount.');
  return { gross, discount, tax, total: gross - discount + tax };
}

function totals(lines) {
  let subtotal = 0n, discount = 0n, tax = 0n, total = 0n;
  const numbers = new Set();
  for (const line of lines) {
    requireThat(!numbers.has(line.lineNumber), 409, 'INVALID_INVOICE_LINE', 'Invoice line numbers must be unique.');
    numbers.add(line.lineNumber);
    const amount = invoiceLineValues(line);
    subtotal += amount.gross; discount += amount.discount; tax += amount.tax; total += amount.total;
  }
  requireThat(subtotal <= 100000000000000n && total <= 100000000000000n, 400, 'INVALID_INVOICE_LINE', 'Invoice exceeds supported limits.');
  return { subtotal: dollars(subtotal), discount: dollars(discount), taxAmount: dollars(tax), total: dollars(total), paidAmount: 0, balance: dollars(total) };
}

export async function invoiceChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (!['Invoices', 'InvoiceItems'].includes(table)) return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'issue', 'invoiceVoid'].includes(action), 400, 'INVALID_INVOICE', 'Unsupported invoice action.');
  if (table === 'Invoices') {
    requireThat(!old || old.status === 'DRAFT' || action === 'invoiceVoid', 409, 'INVOICE_LOCKED', 'Only draft invoices can be edited.');
    if (action === 'issue') {
      const data = await sheets.read(companyId, ['Invoices', 'InvoiceItems', 'CompanyProfile', 'Journals', 'JournalLines']);
      const lines = data.InvoiceItems.filter(line => line.companyId === companyId && line.invoiceId === id && active(line));
      requireThat(lines.length > 0, 409, 'INVOICE_EMPTY', 'Add at least one invoice line before issuing.');
      const calculated = totals(lines);
      requireThat(old && old.customerId && validLedgerDate(old.issueDate) && /^[A-Z]{3}$/.test(old.currency) &&
        old.subtotal === calculated.subtotal && old.discount === calculated.discount && old.taxAmount === calculated.taxAmount && old.total === calculated.total,
      409, 'INVOICE_TOTAL_MISMATCH', 'Refresh or repair invoice totals before issuing.');
      await assertOpenLedgerDate(sheets, companyId, old.issueDate);
      const profile = data.CompanyProfile.find(row => row.companyId === companyId && active(row));
      const prefix = String(profile?.invoicePrefix || 'INV').trim().toUpperCase();
      requireThat(/^[A-Z0-9-]{1,12}$/.test(prefix), 409, 'INVALID_INVOICE_PREFIX', 'Configure a valid invoice prefix.');
      const period = old.issueDate.slice(0, 4), pattern = new RegExp(`^${prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}-${period}-(\\d{6})$`);
      const sequence = Math.max(0, ...data.Invoices.filter(row => row.companyId === companyId && active(row)).map(row => pattern.exec(row.number)?.[1]).filter(Boolean).map(Number)) + 1;
      requireThat(sequence <= 999999, 409, 'INVOICE_SEQUENCE_EXHAUSTED', 'Invoice numbering is exhausted for this year.');
      const number = `${prefix}-${period}-${String(sequence).padStart(6, '0')}`;
      const journalId = challenge(`${companyId}:${operation}:invoice-issue`);
      const journalRow = Math.max(1, ...data.Journals.map(row => row._row)) + 1;
      const lineRow = Math.max(1, ...data.JournalLines.map(row => row._row)) + 1;
      const revenue = dollars(minor(calculated.total) - minor(calculated.taxAmount));
      const entries = [
        { accountId: 'accounts_receivable', accountName: 'Accounts Receivable', accountGroup: 'Asset', debit: calculated.total, credit: 0 },
        { accountId: 'service_consulting_revenue', accountName: 'Service & Consulting Revenue', accountGroup: 'Income', debit: 0, credit: revenue },
        ...(calculated.taxAmount > 0 ? [{ accountId: 'output_vat_payable', accountName: 'Output VAT Payable', accountGroup: 'Liability', debit: 0, credit: calculated.taxAmount }] : []),
      ];
      const journalSystem = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
      return { values: { ...calculated, status: 'ISSUED', number }, extra: [
        { table: 'Journals', row: journalRow, values: { ...journalSystem, recordId: journalId, number: `AUTO-${journalId}`,
          date: old.issueDate, description: `Invoice ${number}`, sourceType: 'Invoice', sourceId: id,
          totalDebit: calculated.total, totalCredit: calculated.total, status: 'POSTED' } },
        ...entries.map((entry, index) => ({ table: 'JournalLines', row: lineRow + index, values: {
          ...journalSystem, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1, ...entry,
        } })),
      ] };
    }
    if (action === 'invoiceVoid') {
      requireThat(Object.keys(values).every(key => ['voidDate', 'voidReason'].includes(key)),
        400, 'INVALID_INVOICE_VOID', 'Invoice void accepts only a date and reason.');
      requireThat(old?.status === 'ISSUED' && minor(old.paidAmount) === 0n && minor(old.balance) === minor(old.total),
        409, 'INVOICE_VOID_NOT_AVAILABLE', 'Reverse every receipt before voiding this invoice.');
      requireThat(validLedgerDate(values.voidDate) && values.voidDate >= old.issueDate &&
        typeof values.voidReason === 'string' && values.voidReason.trim().length >= 3 && values.voidReason.trim().length <= 1000,
      400, 'INVALID_INVOICE_VOID', 'Enter a valid void date and reason.');
      await assertOpenLedgerDate(sheets, companyId, values.voidDate);
      const data = await sheets.read(companyId, ['Journals', 'JournalLines', 'ReceiptAllocations', 'Receipts']);
      const allocations = data.ReceiptAllocations.filter(row => row.companyId === companyId && row.invoiceId === id && active(row));
      const liveReceipts = new Set(data.Receipts.filter(row => row.companyId === companyId && active(row) && row.status !== 'REVERSED').map(row => row.recordId));
      requireThat(!allocations.some(row => liveReceipts.has(row.receiptId)), 409, 'INVOICE_VOID_NOT_AVAILABLE', 'Reverse every receipt before voiding this invoice.');
      const issued = data.Journals.filter(row => row.companyId === companyId && active(row) && row.status === 'POSTED' && row.sourceType === 'Invoice' && row.sourceId === id);
      const priorVoid = data.Journals.some(row => row.companyId === companyId && active(row) && row.status === 'POSTED' && row.sourceType === 'InvoiceVoid' && row.sourceId === id);
      requireThat(issued.length === 1 && !priorVoid, 409, 'INVOICE_LEDGER_MISMATCH', 'The invoice ledger history cannot be reversed safely.');
      const original = data.JournalLines.filter(row => row.companyId === companyId && active(row) && row.journalId === issued[0].recordId)
        .sort((a, b) => Number(a.lineNumber) - Number(b.lineNumber));
      requireThat(original.length >= 2 && original.every(row => minor(row.debit) >= 0n && minor(row.credit) >= 0n && (minor(row.debit) === 0n) !== (minor(row.credit) === 0n)),
        409, 'INVOICE_LEDGER_MISMATCH', 'The invoice ledger history cannot be reversed safely.');
      const debit = original.reduce((sum, row) => sum + minor(row.credit), 0n);
      const credit = original.reduce((sum, row) => sum + minor(row.debit), 0n);
      requireThat(debit === credit && debit === minor(old.total), 409, 'INVOICE_LEDGER_MISMATCH', 'The invoice ledger history cannot be reversed safely.');
      const journalId = challenge(`${companyId}:${operation}:invoice-void`);
      const journalRow = Math.max(1, ...data.Journals.map(row => row._row)) + 1;
      const lineRow = Math.max(1, ...data.JournalLines.map(row => row._row)) + 1;
      const journalSystem = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
      return { values: { voidDate: values.voidDate, voidReason: values.voidReason.trim(), status: 'VOID', balance: 0 }, extra: [
        { table: 'Journals', row: journalRow, values: { ...journalSystem, recordId: journalId, number: `AUTO-${journalId}`,
          date: values.voidDate, description: `Void invoice ${old.number}: ${values.voidReason.trim()}`, sourceType: 'InvoiceVoid', sourceId: id,
          totalDebit: dollars(debit), totalCredit: dollars(credit), status: 'POSTED' } },
        ...original.map((entry, index) => ({ table: 'JournalLines', row: lineRow + index, values: {
          ...journalSystem, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1,
          accountId: entry.accountId, accountName: entry.accountName, accountGroup: entry.accountGroup,
          debit: entry.credit, credit: entry.debit,
        } })),
      ] };
    }
    if (action === 'delete') return { values, extra: [] };
    requireThat(!Object.keys(values).some(k => ['subtotal', 'discount', 'taxAmount', 'total', 'paidAmount', 'balance', 'number'].includes(k)),
      400, 'INVOICE_DERIVED_FIELD', 'Invoice totals and numbering are assigned by the server.');
    const record = { ...old, ...values, status: values.status ?? old?.status ?? 'DRAFT' };
    requireThat(record.status === 'DRAFT', 409, 'INVOICE_LOCKED', 'Issuing requires the invoice posting workflow.');
    requireThat(typeof record.customerId === 'string' && record.customerId && validLedgerDate(record.issueDate) &&
      (!record.dueDate || (validLedgerDate(record.dueDate) && record.dueDate >= record.issueDate)) &&
      typeof record.currency === 'string' && /^[A-Z]{3}$/.test(record.currency),
    400, 'INVALID_INVOICE', 'Choose a customer, currency and valid invoice dates.');
    const data = await sheets.read(companyId, ['InvoiceItems']);
    const lines = data.InvoiceItems.filter(l => l.companyId === companyId && l.invoiceId === id && active(l));
    const { items, ...header } = values;
    const replacement = items === undefined ? { lines, extra: [] } :
      replaceDraftItems(companyId, 'InvoiceItems', 'invoiceId', id, data.InvoiceItems,
        items, system, operation, invoiceLineValues);
    return { values: { ...header, status: 'DRAFT', ...totals(replacement.lines) }, extra: replacement.extra };
  }
  const next = { ...old, ...values };
  requireThat(!old || old.invoiceId === next.invoiceId, 409, 'INVOICE_LOCKED', 'Moving invoice lines is not supported.');
  const data = await sheets.read(companyId, ['Invoices', 'InvoiceItems']);
  const parent = data.Invoices.find(i => i.companyId === companyId && i.recordId === next.invoiceId && active(i));
  requireThat(parent?.status === 'DRAFT', 409, 'INVOICE_LOCKED', 'Only draft invoice lines can change.');
  requireThat(Number.isSafeInteger(Number(parent.recordVersion)) && Number(parent.recordVersion) > 0,
    409, 'INVALID_INVOICE', 'Invoice version is invalid.');
  let write = values;
  if (action !== 'delete') {
    const amount = invoiceLineValues(next);
    for (const [key, expected] of [['taxAmount', amount.tax], ['lineTotal', amount.total]]) {
      requireThat(!Object.hasOwn(values, key) || minor(values[key]) === expected, 400, 'INVOICE_TOTAL_MISMATCH', 'Line totals do not match calculated amounts.');
    }
    write = { ...values, discount: next.discount ?? 0, taxRate: next.taxRate ?? 0, taxAmount: dollars(amount.tax), lineTotal: dollars(amount.total) };
  }
  const lines = data.InvoiceItems.filter(l => l.companyId === companyId && l.invoiceId === parent.recordId && l.recordId !== id && active(l));
  if (action !== 'delete') lines.push({ ...next, ...write });
  return { values: write, extra: [{ table: 'Invoices', row: parent._row, values: {
    ...totals(lines), updatedAt: system.updatedAt, updatedBy: system.updatedBy,
    recordVersion: Number(parent.recordVersion) + 1, syncStatus: 'SYNCED', idempotencyKey: system.idempotencyKey,
  } }] };
}
