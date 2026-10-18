import { requireThat } from './errors.js';

export const documentSections = ['Invoices', 'Quotations', 'Receipts', 'CreditNotes', 'Payroll'];
export function documentTables(section) {
  if(section==='Payroll')return ['Payroll','Employees','CompanyProfile'];
  return [section, ...({ Invoices: ['InvoiceItems'], Quotations: ['QuotationItems'],
    Receipts: ['ReceiptAllocations', 'Invoices'], CreditNotes: ['CreditNoteItems', 'Invoices'] }[section] ?? []),
    'CompanyProfile', 'Customers'];
}
export const defaultDesign = "<style>\n@page { size: A4; margin: 18mm; }\nbody { font: 14px Arial, sans-serif; color: #202124; margin: 32px; }\nheader { display:flex; justify-content:space-between; border-bottom:2px solid #1677ff; padding-bottom:20px; }\nh1 { margin:0; font-size:28px; } h2 { font-size:18px; }\n.details { display:flex; justify-content:space-between; margin:28px 0; }\ntable { border-collapse:collapse; width:100%; }\nth, td { padding:12px; border-bottom:1px solid #ddd; text-align:right; }\nth:first-child, td:first-child { text-align:left; }\nth { background:#f4f6f8; } .totals { margin:24px 0 24px auto; width:300px; }\nfooter { border-top:1px solid #ddd; margin-top:32px; padding-top:16px; }\n</style>\n<header><div><h2>{{company.name}}</h2>{{company.address}}<br>TRN: {{company.trn}}<br>{{company.email}}</div>\n<div><h1>{{title}}</h1>{{record.number}}<br>{{record.status}}</div></header>\n<div class=\"details\"><div><b>Bill to</b><h2>{{customer.name}}</h2>{{customer.address}}<br>TRN: {{customer.trn}}</div>\n<div>Issue date: {{record.issueDate}}<br>Due / valid until: {{endDate}}<br>Currency: {{record.currency}}</div></div>\n<table><thead><tr><th>Description</th><th>Quantity</th><th>Unit price</th><th>Discount</th><th>VAT %</th><th>Amount</th></tr></thead><tbody>{{items}}</tbody></table>\n<div class=\"totals\">Subtotal: {{record.subtotal}}<br>Discount: {{record.discount}}<br>VAT: {{record.taxAmount}}<h2>Total: {{record.currency}} {{record.total}}</h2></div>\n<footer><b>Notes</b><p>{{record.notes}}</p><b>Terms</b><p>{{record.paymentTerms}}</p></footer>";
export function validateDesign(source) {
  requireThat(typeof source === 'string' && source.trim() && new TextEncoder().encode(source).length <= 100000,
    400, 'INVALID_DOCUMENT_DESIGN', 'Use a non-empty HTML design up to 100 KB.');
  requireThat(source.includes('{{items}}') && source.includes('{{record.total}}'),
    400, 'INVALID_DOCUMENT_DESIGN', 'Include {{items}} and {{record.total}} in the design.');
  for (const match of source.matchAll(/\{\{([^{}]+)\}\}/g)) {
    requireThat(['title', 'endDate', 'items'].includes(match[1].trim()) ||
      /^(company|customer|record)\.[a-zA-Z][a-zA-Z0-9]*$/.test(match[1].trim()),
    400, 'INVALID_DOCUMENT_DESIGN', 'Unknown HTML placeholder.');
  }
}
export function companyDesign(company, section) {
  requireThat(documentSections.includes(section), 400, 'INVALID_DOCUMENT_SECTION', 'Choose an invoice, quotation, receipt, credit note / return or payslip.');
  return company.documentDesigns?.[section] ?? { source: section==='Payroll'?defaultPayslipDesign:defaultDesign, version: 0 };
}
export const defaultPayslipDesign = `<style>
@page { size:A4; margin:18mm } body { font:14px Arial,sans-serif; color:#202124 }
header { border-bottom:2px solid #1677ff; padding-bottom:16px } h1 { margin:8px 0 }
table { width:100%; border-collapse:collapse; margin-top:24px } th,td { padding:12px; border-bottom:1px solid #ddd; text-align:left } th:last-child,td:last-child { text-align:right }
.net { text-align:right; margin-top:24px; font-size:20px } footer { margin-top:32px }
</style><header><h2>{{company.name}}</h2>{{company.address}}<h1>{{title}}</h1>Pay period: {{record.month}}</header>
<h2>{{record.employeeName}}</h2>Employee code: {{record.employeeCode}}<br>Department: {{record.department}}<br>Designation: {{record.designation}}<br>Status: {{record.status}}<br>Currency: {{record.currency}}
<table><thead><tr><th>Component</th><th>Amount</th></tr></thead><tbody>{{items}}</tbody></table>
<div class="net">Net pay: {{record.currency}} {{record.total}}</div><footer>Paid date: {{record.paidDate}}<br>Payment reference: {{record.paymentReference}}</footer>`;
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = value => escape(typeof value === 'number' ? value.toFixed(2) : value);
export function companyLogo(company) {
  const data=company.logoDataUrl;
  if(typeof data!=='string'||!/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/]+={0,2}$/.test(data))return '';
  return `<img class="company-logo" src="${data}" alt="${escape(company.name)} logo" style="display:block;max-width:160px;max-height:80px;object-fit:contain;margin-bottom:12px">`;
}
export function renderDocumentHtml(source, section, record, company, customer, items) {
  validateDesign(source);
  const rows = items.map(item => section==='Payroll'
    ? `<tr><td>${escape(item.description)}</td><td>${money(item.lineTotal)}</td></tr>`
    : `<tr><td>${escape(item.description)}</td><td>${escape(item.quantity)}</td><td>${money(item.unitPrice)}</td><td>${money(item.discount)}</td><td>${escape(item.taxRate)}</td><td>${money(item.lineTotal)}</td></tr>`).join('');
  const logo=companyLogo(company);
  const hasLogoPlaceholder=/\{\{\s*company\.(logo|logoDataUrl)\s*\}\}/.test(source);
  const content = (hasLogoPlaceholder?'':logo) + source.replace(/\{\{([^{}]+)\}\}/g, (_, raw) => {
    const token = raw.trim();
    if(token==='company.logo')return logo;
    if(token==='company.logoDataUrl')return logo?escape(company.logoDataUrl):'';
    if (token === 'items') return rows;
    if (token === 'title') return ({Invoices:'INVOICE',Quotations:'QUOTATION',Receipts:'PAYMENT RECEIPT',CreditNotes:'CREDIT NOTE / RETURN',Payroll:'PAYSLIP'})[section];
    if (token === 'endDate') return escape(record[section === 'Invoices' ? 'dueDate' : 'validUntil']);
    const [kind, field] = token.split('.');
    const data = { record, company: { ...company, trn: company.trn ?? company.taxNumber }, customer: { ...customer, trn: customer.trn ?? customer.taxNumber } }[kind];
    return money(data[field]);
  });
  return `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; base-uri 'none'; form-action 'none'"></head><body>${content}</body></html>`;
}

export function snapshotHtml(source, section, recordId, rows) {
  const active = r => r.isDeleted !== true && r.isDeleted !== 'TRUE';
  let record = rows[section].find(r => r.recordId === recordId && active(r));
  requireThat(record, 404, 'RECORD_UNAVAILABLE', 'Document record is unavailable.');
  const company = rows.CompanyProfile.find(r => r.recordId === 'company' && active(r));
  const invoice = section === 'CreditNotes' ? rows.Invoices.find(r => r.recordId === record.invoiceId && active(r)) : null;
  const customer = section==='Payroll'
    ? rows.Employees.find(r => r.recordId===record.employeeId && active(r))
    : rows.Customers.find(r => r.recordId === (record.customerId ?? invoice?.customerId) && active(r));
  requireThat(company && customer, 409, 'RECORD_UNAVAILABLE', 'Company or customer is unavailable.');
  const itemTable = {Invoices:'InvoiceItems',Quotations:'QuotationItems',CreditNotes:'CreditNoteItems'}[section];
  const parentKey = {Invoices:'invoiceId',Quotations:'quotationId',CreditNotes:'creditNoteId'}[section];
  let items = itemTable ? rows[itemTable].filter(r => active(r) && r[parentKey] === recordId)
    .sort((a, b) => Number(a.lineNumber) - Number(b.lineNumber)) : [];
  if(section === 'Receipts') {
    items = rows.ReceiptAllocations.filter(r => active(r) && r.receiptId === recordId).map(r => ({
      description: `Payment for invoice ${rows.Invoices.find(i => i.recordId === r.invoiceId)?.number ?? r.invoiceId}`,
      quantity:1,unitPrice:r.amount,discount:0,taxRate:0,lineTotal:r.amount,
    }));
    if(!items.length)items=[{description:record.reference||'Payment received',quantity:1,unitPrice:record.amount,discount:0,taxRate:0,lineTotal:record.amount}];
    record={...record,issueDate:record.paymentDate,total:record.amount,subtotal:record.amount,discount:0,taxAmount:0,
      notes:record.reference,paymentTerms:record.paymentAccount};
  }
  if(section === 'CreditNotes')record={...record,issueDate:record.date,invoiceNumber:invoice?.number,
    notes:`Credit for invoice ${invoice?.number ?? record.invoiceId}. ${record.reason ?? ''}`,
    paymentTerms:`Refund: ${record.refundAmount ?? 0} ${record.currency ?? ''} ${record.refundAccount ?? ''}`};
  if(section === 'Payroll') {
    items=[['Basic salary','basicSalary'],['Allowances','allowances'],['Overtime','overtimeAmount'],
      ['Bonus','bonus'],['Gross salary','grossSalary'],['Deductions','deductions']]
      .map(([description,field])=>({description,lineTotal:record[field]??0}));
    record={...record,total:record.netSalary,employeeName:customer.fullName,employeeCode:customer.employeeCode,
      department:customer.department,designation:customer.designation,
      currency:record.currency||customer.currency||company.currency};
  }
  return renderDocumentHtml(source, section, record, company, customer, items);
}

