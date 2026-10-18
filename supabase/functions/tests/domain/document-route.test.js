import test from 'node:test';
import assert from 'node:assert/strict';
import { documentRoute } from '../../_shared/domain/document-route.js';

test('template and HTML endpoints resolve canonical and display names', () => {
  const id='r'.repeat(43);
  for(const [section,aliases] of Object.entries({
    CreditNotes:['CreditNotes','CreditNote','credit-note','Credit%20note'],
    Payroll:['Payroll','Payslip','Payslips','payslip'],
    Receipts:['Receipts','Receipt','receipt'],
    Invoices:['Invoices'],Quotations:['Quotations'],
  })) {
    for(const alias of aliases) {
      assert.deepEqual(documentRoute(`/document-designs/${alias}`),{kind:'document-designs',section,recordId:undefined});
      assert.deepEqual(documentRoute(`/record-html/${alias}/${id}`),{kind:'record-html',section,recordId:id});
    }
  }
  assert.equal(documentRoute('/records/Payroll'),null);
  assert.equal(documentRoute('/record-html/Payroll/not-a-record'),null);
});
