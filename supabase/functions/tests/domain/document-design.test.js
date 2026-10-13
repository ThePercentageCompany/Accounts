import test from 'node:test';
import assert from 'node:assert/strict';
import { defaultDesign, renderDocumentHtml, validateDesign, companyDesign } from '../../_shared/domain/document-design.js';

test('HTML keeps company CSS and embeds escaped document values and saved totals', () => {
  const source = '<style>@page{size:A5}h1{color:purple}</style><h1>{{title}}</h1>{{company.trn}}{{customer.name}}<table>{{items}}</table>{{record.total}}';
  const html = renderDocumentHtml(source, 'Invoices', { total: 123.45 }, { taxNumber: 'TRN123' },
    { name: '<script>alert(1)</script>' }, [{ description: 'A&B', quantity: 1, unitPrice: 100, discount: 0, taxRate: 5, lineTotal: 105 }]);
  assert.ok(html.includes('<style>@page{size:A5}h1{color:purple}</style>'));
  assert.ok(html.includes('INVOICE')); assert.ok(html.includes('123.45'));
  assert.ok(html.includes('TRN123')); assert.ok(html.includes('A&amp;B'));
  assert.ok(html.includes('&lt;script&gt;')); assert.ok(html.includes("default-src 'none'"));
  assert.ok(renderDocumentHtml(source, 'Quotations', {}, {}, {}, []).includes('QUOTATION'));
});

test('designs are separate for invoices and quotations and malformed sources are rejected', () => {
  assert.equal(companyDesign({}, 'Invoices').source, defaultDesign);
  const design = { source: defaultDesign + '<p>Company design</p>', version: 3 };
  assert.deepEqual(companyDesign({ documentDesigns: { Invoices: design } }, 'Invoices'), design);
  assert.equal(companyDesign({ documentDesigns: { Invoices: design } }, 'Quotations').version, 0);
  for (const source of ['', 'No placeholders', '{{items}}{{record.total}}{{unknown}}', 'x'.repeat(100001), null]) {
    assert.throws(() => validateDesign(source), e => e.code === 'INVALID_DOCUMENT_DESIGN');
  }
  assert.throws(() => companyDesign({}, 'Customers'));
});
