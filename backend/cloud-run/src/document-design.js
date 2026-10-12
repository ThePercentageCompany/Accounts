import { readFileSync } from 'node:fs';
import { requireThat } from './errors.js';

export const documentSections = ['Invoices', 'Quotations'];
export const defaultDesign = readFileSync(new URL('./default-document-design.html', import.meta.url), 'utf8');
export function validateDesign(source) {
  requireThat(typeof source === 'string' && source.trim() && Buffer.byteLength(source) <= 100000,
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

let activeRenders = 0;
export async function htmlPdf(html) {
  requireThat(activeRenders < 2, 503, 'PDF_BUSY', 'PDF generation is busy. Retry shortly.');
  activeRenders++;
  let browser;
  try {
    const { chromium } = await import('playwright');
    browser = await chromium.launch({ headless: true, timeout: 15000, args: ['--disable-dev-shm-usage'] });
    const context = await browser.newContext({ javaScriptEnabled: false, serviceWorkers: 'block' });
    await context.route('**/*', route => route.abort());
    const page = await context.newPage();
    page.setDefaultTimeout(15000);
    await page.setContent(html, { waitUntil: 'load' });
    return await page.pdf({ format: 'A4', preferCSSPageSize: true, printBackground: true, timeout: 15000 });
  } finally {
    try { await browser?.close(); } finally { activeRenders--; }
  }
}
