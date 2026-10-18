import { requireThat } from './errors.js';

export function documentSection(value) {
  const key = value.replace(/[\s_-]/g, '').toLowerCase();
  const section = ({ invoice:'Invoices', invoices:'Invoices', quotation:'Quotations', quotations:'Quotations',
    receipt:'Receipts', receipts:'Receipts', creditnote:'CreditNotes', creditnotes:'CreditNotes',
    payslip:'Payroll', payslips:'Payroll', payroll:'Payroll' })[key];
  requireThat(section,400,'INVALID_DOCUMENT_SECTION','Choose Invoice, Quotation, Credit note, Payslip or Receipt.');
  return section;
}

export function documentRoute(tail) {
  const match = /^\/(document-designs|record-html)\/([^/]+)(?:\/([A-Za-z0-9_-]{43}))?\/?$/.exec(tail);
  if (!match) return null;
  if ((match[1] === 'record-html') !== !!match[3]) return null;
  let section;
  try { section = decodeURIComponent(match[2]); } catch { return null; }
  return {kind:match[1],section:documentSection(section),recordId:match[3]};
}
