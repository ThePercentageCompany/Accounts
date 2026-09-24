import test from 'node:test';
import assert from 'node:assert/strict';
import { validateRelations } from '../src/business-relations.js';

const id = 'i'.repeat(43), company = 'company';
const sheets = data => ({ read: async (_company, names) => Object.fromEntries(names.map(name => [name, data[name] || []])) });

test('employee references use internal reads and payslips must match payroll ownership', async () => {
  const employeeId = 'e'.repeat(43);
  const data = { Employees: [{ recordId: employeeId, companyId: company, employmentStatus: 'INACTIVE' }],
    Payroll: [{ recordId: id, companyId: company, employeeId }] };
  const adapter = sheets(data);
  adapter.readReferences = adapter.read;
  await validateRelations(adapter, company, 'Payroll', null, 'create', { employeeId });
  await validateRelations(adapter, company, 'Payslips', null, 'create', { employeeId, payrollId: id });
  data.Payroll[0].employeeId = 'x'.repeat(43);
  await assert.rejects(() => validateRelations(adapter, company, 'Payslips', null, 'create', { employeeId, payrollId: id }), e => e.code === 'REFERENCE_MISMATCH');
  data.Employees[0].isDeleted = true;
  await assert.rejects(() => validateRelations(adapter, company, 'Attendance', null, 'create', { employeeId }), e => e.code === 'REFERENCE_NOT_FOUND');
});

test('relationships reject missing, deleted and foreign-company parents', async () => {
  for (const rows of [[], [{ recordId: id, companyId: company, isDeleted: true }], [{ recordId: id, companyId: 'other' }]]) {
    await assert.rejects(() => validateRelations(sheets({ Invoices: rows }), company, 'InvoiceItems', null, 'create', { invoiceId: id }),
      e => e.code === 'REFERENCE_NOT_FOUND');
  }
  await validateRelations(sheets({ Invoices: [{ recordId: id, companyId: company }] }), company, 'InvoiceItems', null, 'create', { invoiceId: id });
});

test('child parents are required and malformed optional references fail', async () => {
  await assert.rejects(() => validateRelations(sheets({}), company, 'InvoiceItems', null, 'create', {}), e => e.code === 'REFERENCE_REQUIRED');
  await assert.rejects(() => validateRelations(sheets({}), company, 'Invoices', null, 'create', { customerId: false }), e => e.code === 'INVALID_REFERENCE');
  await validateRelations(sheets({}), company, 'Invoices', null, 'create', { customerId: '' });
});

test('parent deletion rejects active dependents but permits deleted dependents', async () => {
  await assert.rejects(() => validateRelations(sheets({ ReceiptAllocations: [{ invoiceId: id }] }), company, 'Invoices', id, 'delete', {}), e => e.code === 'RECORD_REFERENCED');
  await validateRelations(sheets({ ReceiptAllocations: [{ invoiceId: id, isDeleted: true }] }), company, 'Invoices', id, 'delete', {});
});
