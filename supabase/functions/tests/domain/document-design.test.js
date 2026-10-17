import test from 'node:test';
import assert from 'node:assert/strict';
import { defaultDesign, defaultPayslipDesign, renderDocumentHtml, validateDesign, companyDesign, snapshotHtml, documentTables } from '../../_shared/domain/document-design.js';

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

test('payslip design renders only the selected payroll and employee with authoritative net pay', () => {
  const rows={CompanyProfile:[{recordId:'company',name:'Business',currency:'AED'}],
    Employees:[{recordId:'employee',fullName:'Aisha',employeeCode:'EMP-1',department:'Sales'},
      {recordId:'other',fullName:'Another employee'}],
    Payroll:[{recordId:'payroll',employeeId:'employee',month:'2026-10',basicSalary:5000,
      allowances:500,overtimeAmount:200,bonus:100,grossSalary:5800,deductions:300,netSalary:5500}]};
  assert.equal(companyDesign({},'Payroll').source,defaultPayslipDesign);
  validateDesign(defaultPayslipDesign);
  assert.deepEqual(documentTables('Payroll'),['Payroll','Employees','CompanyProfile']);
  const html=snapshotHtml(defaultPayslipDesign,'Payroll','payroll',rows);
  for(const value of ['PAYSLIP','Aisha','EMP-1','Sales','2026-10','5500.00','5800.00','300.00','AED'])assert.ok(html.includes(value));
  assert.ok(!html.includes('Another employee'));
  assert.throws(()=>snapshotHtml(defaultPayslipDesign,'Payroll','missing',rows),e=>e.code==='RECORD_UNAVAILABLE');
});

test('receipt and credit note / return designs render their own authoritative data', () => {
  const rows = {
    CompanyProfile:[{recordId:'company',name:'Company'}],Customers:[{recordId:'customer',name:'Customer'}],
    Invoices:[{recordId:'invoice',number:'INV-1',customerId:'customer'}],
    Receipts:[{recordId:'receipt',customerId:'customer',amount:105,paymentDate:'2026-10-17',currency:'AED'}],
    ReceiptAllocations:[{receiptId:'receipt',invoiceId:'invoice',amount:105}],
    CreditNotes:[{recordId:'credit',invoiceId:'invoice',date:'2026-10-17',total:52.5,reason:'Returned goods'}],
    CreditNoteItems:[{creditNoteId:'credit',description:'Returned product',quantity:1,lineTotal:52.5},
      {creditNoteId:'other',description:'Unrelated product'}],
  };
  const source='{{title}} {{record.issueDate}} {{record.notes}} {{items}} {{record.total}} {{customer.name}}';
  const receipt=snapshotHtml(source,'Receipts','receipt',rows);
  assert.ok(receipt.includes('PAYMENT RECEIPT'));
  assert.ok(receipt.includes('105.00')&&receipt.includes('2026-10-17')&&receipt.includes('Payment for invoice INV-1'));
  const credit=snapshotHtml(source,'CreditNotes','credit',rows);
  assert.ok(credit.includes('CREDIT NOTE / RETURN')&&credit.includes('Returned goods')&&credit.includes('Customer'));
  assert.ok(credit.includes('52.50')&&credit.includes('Returned product')&&!credit.includes('Unrelated product'));
  for(const section of ['Receipts','CreditNotes']) {
    assert.equal(companyDesign({},section).version,0);
    assert.ok(documentTables(section).includes('Invoices'));
    const saved={source,version:1};
    assert.deepEqual(companyDesign({documentDesigns:{[section]:saved}},section),saved);
  }
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
