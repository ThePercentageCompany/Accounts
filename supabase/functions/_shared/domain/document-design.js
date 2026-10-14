import { requireThat } from './errors.js';

export const documentSections = ['Invoices', 'Quotations'];
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
  requireThat(documentSections.includes(section), 400, 'INVALID_DOCUMENT_SECTION', 'Choose invoices or quotations.');
  return company.documentDesigns?.[section] ?? { source: defaultDesign, version: 0 };
}
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = value => escape(typeof value === 'number' ? value.toFixed(2) : value);
export function renderDocumentHtml(source, section, record, company, customer, items) {
  validateDesign(source);
  const rows = items.map(item => `<tr><td>${escape(item.description)}</td><td>${escape(item.quantity)}</td><td>${money(item.unitPrice)}</td><td>${money(item.discount)}</td><td>${escape(item.taxRate)}</td><td>${money(item.lineTotal)}</td></tr>`).join('');
  const content = source.replace(/\{\{([^{}]+)\}\}/g, (_, raw) => {
    const token = raw.trim();
    if (token === 'items') return rows;
    if (token === 'title') return section === 'Invoices' ? 'INVOICE' : 'QUOTATION';
    if (token === 'endDate') return escape(record[section === 'Invoices' ? 'dueDate' : 'validUntil']);
    const [kind, field] = token.split('.');
    const data = { record, company: { ...company, trn: company.trn ?? company.taxNumber }, customer: { ...customer, trn: customer.trn ?? customer.taxNumber } }[kind];
    return money(data[field]);
  });
  return `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; base-uri 'none'; form-action 'none'"></head><body>${content}</body></html>`;
}

export function snapshotHtml(source, section, recordId, rows) {
  const active = r => r.isDeleted !== true && r.isDeleted !== 'TRUE';
  const record = rows[section].find(r => r.recordId === recordId && active(r));
  requireThat(record, 404, 'RECORD_UNAVAILABLE', 'Document record is unavailable.');
  const company = rows.CompanyProfile.find(r => r.recordId === 'company' && active(r));
  const customer = rows.Customers.find(r => r.recordId === record.customerId && active(r));
  requireThat(company && customer, 409, 'RECORD_UNAVAILABLE', 'Company or customer is unavailable.');
  const invoice = section === 'Invoices';
  const items = rows[invoice ? 'InvoiceItems' : 'QuotationItems'].filter(r => active(r) &&
    r[invoice ? 'invoiceId' : 'quotationId'] === recordId).sort((a, b) => Number(a.lineNumber) - Number(b.lineNumber));
  return renderDocumentHtml(source, section, record, company, customer, items);
}

