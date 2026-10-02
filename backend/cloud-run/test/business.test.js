import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { BusinessService } from '../src/business-service.js';
import { ApiError } from '../src/errors.js';
import { TABLES } from '../src/company-schema.js';

async function setup() {
  const f = fixture(), token = await f.login(), registration = await f.service.createCompany(token, { name: 'Business' }, 'company_business_123');
  const companyId = registration.company.companyId;
  await f.registry.transact(state => { state.companies[companyId].stage = 'READY'; });
  const data = { Customers: [] };
  const sheets = {
    table(name) { if (name !== 'Customers') throw new ApiError(403, 'TABLE_FORBIDDEN', 'Unavailable');
      return { headers: ['recordId', 'companyId', 'name', 'email'] }; },
    async read(id, names) { assert.equal(id, companyId); return Object.fromEntries(names.map(name => [name, structuredClone(data[name] || [])])); },
    async write(id, table, row, values) {
      assert.equal(id, companyId); const existing = data[table].find(item => item._row === row);
      if (existing) Object.assign(existing, values); else data[table].push({ ...values, _row: row });
    },
  };
  return { ...f, token, companyId, data, sheets, business: new BusinessService({ accounts: f.service, sheets, now: () => 1_800_000_000_000 }) };
}

test('company profile validates identity and locks established currency after posting', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.CompanyProfile = [{ recordId: 'company', companyId: f.companyId, name: 'Business', currency: 'AED', recordVersion: 1, _row: 2 }];
  f.data.Journals = [{ companyId: f.companyId, status: 'POSTED' }];
  for (const [values, code] of [[{ name: '' }, 'INVALID_COMPANY_PROFILE'], [{ invoicePrefix: 'bad prefix' }, 'INVALID_COMPANY_PROFILE'],
    [{ currency: 'USD' }, 'COMPANY_CURRENCY_LOCKED']]) {
    await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update',
      { expectedVersion: 1, values }, `profile_invalid_${code}`), e => e.code === code);
  }
  await f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update',
    { expectedVersion: 1, values: { name: 'Updated', invoicePrefix: 'TPC', currency: 'AED' } }, 'profile_valid_0001');
  assert.equal(f.data.CompanyProfile[0].name, 'Updated'); assert.equal(f.data.CompanyProfile[0].recordVersion, 2);
});

test('dashboard and general ledger reject foreign owners and pending writes', async () => {
  const f = await setup(), other = await f.login('other');
  for (const kind of ['dashboard', 'general-ledger']) {
    await assert.rejects(() => f.business.report(other, f.companyId, kind, '2026-09-01', '2026-09-30'));
    const report = await f.business.report(f.token, f.companyId, kind, '2026-09-01', '2026-09-30');
    assert.equal(report.journalCount, 0);
  }
  await f.registry.transact(state => { state.companies[f.companyId].businessWrite = 'pending'; });
  await assert.rejects(() => f.business.report(f.token, f.companyId, 'dashboard', '2026-09-01', '2026-09-30'), e => e.code === 'BUSINESS_WRITE_PENDING');
});

test('invoice line retry reconciles atomic header totals without a duplicate parent update', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.Invoices = []; f.data.InvoiceItems = [];
  const customer = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'Customer' } }, 'invoice_customer_001');
  const invoice = await f.business.mutate(f.token, f.companyId, 'Invoices', null, 'create',
    { expectedVersion: 0, values: { customerId: customer.recordId, issueDate: '2026-09-27', currency: 'AED' } }, 'invoice_header_001');
  let batches = 0;
  f.sheets.writeBatch = async (id, changes) => {
    batches++;
    for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values);
    throw new Error('response lost');
  };
  const input = { expectedVersion: 0, values: { invoiceId: invoice.recordId, lineNumber: 1, description: 'Service', quantity: 3, unitPrice: 0.1, discount: 0.05, taxRate: 5 } };
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'InvoiceItems', null, 'create', input, 'invoice_line_001x'));
  await f.business.mutate(f.token, f.companyId, 'InvoiceItems', null, 'create', input, 'invoice_line_001x');
  assert.equal(batches, 1); assert.equal(f.data.InvoiceItems.length, 1);
  assert.equal(f.data.Invoices[0].total, 0.26); assert.equal(f.data.Invoices[0].recordVersion, 2);
  assert.equal((await f.business.list(f.token, f.companyId, 'InvoiceItems'))[0].parentStatus, 'DRAFT');
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'update',
    { expectedVersion: 1, values: { notes: 'Stale edit' } }, 'invoice_stale_edit'), e => e.code === 'VERSION_CONFLICT');
  Object.assign(f.data, { CompanyProfile: [{ companyId: f.companyId, invoicePrefix: 'TPC' }],
    Journals: [], JournalLines: [], FinancialPeriods: [] });
  f.sheets.writeBatch = async (id, changes) => {
    batches++;
    for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values);
  };
  const issued = await f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'issue',
    { expectedVersion: 2 }, 'invoice_issue_001x');
  assert.equal(issued.version, 3); assert.equal(f.data.Invoices[0].number, 'TPC-2026-000001');
  assert.equal(f.data.Invoices[0].status, 'ISSUED'); assert.equal(f.data.Journals.length, 1);
  assert.equal(f.data.JournalLines.length, 3); assert.equal(batches, 2);
  await f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'issue',
    { expectedVersion: 2 }, 'invoice_issue_001x');
  assert.equal(batches, 2); assert.equal(f.data.Journals.length, 1);
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'issue',
    { expectedVersion: 3 }, 'invoice_issue_again'), e => e.code === 'INVOICE_LOCKED');
  const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { await write(...args); throw new Error('response lost'); };
  const voidInput = { expectedVersion: 3, values: { voidDate: '2026-09-30', voidReason: 'Customer cancelled order' } };
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'invoiceVoid', voidInput, 'invoice_void_001x'));
  const voided = await f.business.mutate(f.token, f.companyId, 'Invoices', invoice.recordId, 'invoiceVoid', voidInput, 'invoice_void_001x');
  assert.equal(voided.version, 4); assert.equal(f.data.Invoices[0].status, 'VOID');
  assert.equal(f.data.Journals.length, 2); assert.equal(f.data.JournalLines.length, 6); assert.equal(batches, 3);
});

test('receipt payment is atomic, server numbered and idempotent after a lost response', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  const customerId = 'c'.repeat(43), invoiceId = 'i'.repeat(43);
  Object.assign(f.data, {
    Customers: [{ companyId: f.companyId, recordId: customerId, name: 'Customer', _row: 2 }],
    Invoices: [{ companyId: f.companyId, recordId: invoiceId, customerId, issueDate: '2026-09-27', currency: 'AED',
      total: 100, paidAmount: 0, balance: 100, status: 'ISSUED', recordVersion: 3, _row: 2 }],
    Receipts: [], ReceiptAllocations: [], Journals: [], JournalLines: [], FinancialPeriods: [],
  });
  let batches = 0;
  f.sheets.writeBatch = async (id, changes) => {
    batches++;
    for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values);
    throw new Error('response lost');
  };
  const operation = { operations: [{ operationId: 'receipt_payment_001', table: 'Receipts', action: 'receive', expectedVersion: 0,
    values: { invoiceId, customerId, paymentDate: '2026-09-28', amount: 25, currency: 'AED', paymentAccount: 'Cash', reference: 'Cash desk' } }] };
  assert.equal((await f.business.sync(f.token, f.companyId, operation)).results[0].status, 'FAILED');
  assert.equal((await f.business.sync(f.token, f.companyId, operation)).results[0].status, 'APPLIED');
  assert.equal(batches, 1); assert.equal(f.data.Receipts.length, 1); assert.equal(f.data.ReceiptAllocations.length, 1);
  assert.equal(f.data.Invoices[0].paidAmount, 25); assert.equal(f.data.Invoices[0].balance, 75);
  assert.equal(f.data.Invoices[0].status, 'PARTIALLY_PAID'); assert.equal(f.data.Journals.length, 1);
  assert.equal(f.data.JournalLines.length, 2);
});

test('quotation finalization and conversion create one retry-safe draft invoice', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  const customerId = 'c'.repeat(43);
  Object.assign(f.data, { Customers: [{ companyId: f.companyId, recordId: customerId, name: 'Customer', _row: 2 }],
    Quotations: [], QuotationItems: [], CompanyProfile: [{ companyId: f.companyId, quotationPrefix: 'TPCQ' }],
    Invoices: [], InvoiceItems: [] });
  f.sheets.writeBatch = async (id, changes) => { for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values); };
  const quotation = await f.business.mutate(f.token, f.companyId, 'Quotations', null, 'create', {
    expectedVersion: 0, values: { customerId, issueDate: '2026-09-28', validUntil: '2026-10-28', currency: 'AED' },
  }, 'quotation_create_001');
  await f.business.mutate(f.token, f.companyId, 'QuotationItems', null, 'create', {
    expectedVersion: 0, values: { quotationId: quotation.recordId, lineNumber: 1, description: 'Service',
      quantity: 2, unitPrice: 50, discount: 5, taxRate: 5 },
  }, 'quotation_line_001');
  await f.business.mutate(f.token, f.companyId, 'Quotations', quotation.recordId, 'send',
    { expectedVersion: 2 }, 'quotation_send_001');
  assert.equal(f.data.Quotations[0].number, 'TPCQ-2026-000001'); assert.equal(f.data.Quotations[0].status, 'SENT');
  let batches = 0;
  f.sheets.writeBatch = async (id, changes) => {
    batches++; for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values);
    throw new Error('response lost');
  };
  const convert = () => f.business.mutate(f.token, f.companyId, 'Quotations', quotation.recordId, 'convert',
    { expectedVersion: 3 }, 'quotation_convert_001');
  await assert.rejects(convert()); await convert();
  assert.equal(batches, 1); assert.equal(f.data.Invoices.length, 1); assert.equal(f.data.InvoiceItems.length, 1);
  assert.equal(f.data.Invoices[0].status, 'DRAFT'); assert.equal(f.data.Invoices[0].total, 99.75);
  assert.equal(f.data.Quotations[0].convertedInvoiceId, f.data.Invoices[0].recordId);
  assert.equal((await f.business.list(f.token, f.companyId, 'QuotationItems'))[0].parentStatus, 'CONVERTED');
});

test('payroll approval and payment post each journal once', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.sheets.readReferences = f.sheets.read;
  const employeeId = 'e'.repeat(43);
  Object.assign(f.data, { Employees: [{ companyId: f.companyId, recordId: employeeId, employmentStatus: 'ACTIVE',
    basicSalary: 5000, allowances: 500 }], Overtime: [], Payroll: [], PayrollItems: [],
    Journals: [], JournalLines: [], FinancialPeriods: [] });
  let batches = 0;
  f.sheets.writeBatch = async (id, changes) => { batches++; for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values); };
  const payroll = await f.business.mutate(f.token, f.companyId, 'Payroll', null, 'create', {
    expectedVersion: 0, values: { month: '2026-09', employeeId, bonus: 250, deductions: 100 },
  }, 'payroll_create_001');
  await f.business.mutate(f.token, f.companyId, 'Payroll', payroll.recordId, 'approve',
    { expectedVersion: 1 }, 'payroll_approve_001');
  assert.equal(f.data.Payroll[0].status, 'APPROVED'); assert.equal(f.data.Payroll[0].netSalary, 5650);
  assert.equal(f.data.Journals[0].sourceType, 'Payroll');
  const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { await write(...args); throw new Error('response lost'); };
  const payment = { operations: [{ operationId: 'payroll_payment_001', table: 'Payroll', action: 'payrollPay',
    recordId: payroll.recordId, expectedVersion: 2,
    values: { paidDate: '2026-10-01', paymentAccount: 'Bank', paymentReference: 'WPS' } }] };
  assert.equal((await f.business.sync(f.token, f.companyId, payment)).results[0].status, 'FAILED');
  assert.equal((await f.business.sync(f.token, f.companyId, payment)).results[0].status, 'APPLIED');
  assert.equal(f.data.Payroll[0].status, 'PAID'); assert.equal(f.data.Journals.length, 2);
  assert.equal(batches, 2);
});

test('capital contribution posts once after a lost response', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  Object.assign(f.data, { Shareholders: [], CapitalTransactions: [], Journals: [], JournalLines: [], FinancialPeriods: [] });
  f.sheets.writeBatch = async (id, changes) => { for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values); };
  const shareholder = await f.business.mutate(f.token, f.companyId, 'Shareholders', null, 'create', {
    expectedVersion: 0, values: { name: 'Founder', email: '', phone: '', role: 'Founder', status: 'ACTIVE', agreedCapital: 25000, investmentDate: '2026-09-01' },
  }, 'shareholder_create_001');
  const contribution = await f.business.mutate(f.token, f.companyId, 'CapitalTransactions', null, 'create', {
    expectedVersion: 0, values: { date: '2026-09-29', capitalAccountId: '', shareholderId: shareholder.recordId,
      kind: 'CAPITAL_CONTRIBUTION', amount: 25000, method: 'PAID', destinationAccount: 'Bank', assetId: '', reference: 'CAP-001' },
  }, 'capital_create_001');
  const write = f.sheets.writeBatch; let batches = 0;
  f.sheets.writeBatch = async (...args) => { batches++; await write(...args); throw new Error('response lost'); };
  const operation = { operations: [{ operationId: 'capital_post_001', table: 'CapitalTransactions', action: 'capitalPost',
    recordId: contribution.recordId, expectedVersion: 1 }] };
  assert.equal((await f.business.sync(f.token, f.companyId, operation)).results[0].status, 'FAILED');
  assert.equal((await f.business.sync(f.token, f.companyId, operation)).results[0].status, 'APPLIED');
  assert.equal(batches, 1); assert.equal(f.data.CapitalTransactions[0].status, 'POSTED');
  assert.equal(f.data.Journals.length, 1); assert.equal(f.data.JournalLines.length, 2);
});

async function cashFixture(table = 'Income', paid = true) {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  for (const name of [table, 'Journals', 'JournalLines', 'FinancialPeriods']) f.data[name] = [];
  f.batchCount = 0;
  f.sheets.writeBatch = async (id, changes) => {
    f.batchCount++;
    for (const change of changes) await f.sheets.write(id, change.table, change.row, change.values);
  };
  const created = await f.business.mutate(f.token, f.companyId, table, null, 'create', {
    expectedVersion: 0, values: { date: '2026-09-26', description: 'Service', amount: 10.1,
      taxRate: 5, paymentStatus: paid ? 'PAID' : 'UNPAID', paidDate: paid ? '2026-09-27' : '', account: 'Bank' },
  }, 'cash_create_fixture_01');
  f.id = created.recordId;
  f.post = (key = 'cash_post_fixture_01') => f.business.sync(f.token, f.companyId, {
    operations: [{ operationId: key, table, action: 'post', recordId: f.id, expectedVersion: 1 }],
  });
  return f;
}

test('owner trial balance denies foreign owners and revoked sessions after reads', async () => {
  const f = await cashFixture(); await f.post();
  const report = await f.business.trialBalance(f.token, f.companyId, '2026-09-27');
  assert.equal(report.journalCount, 2); assert.equal(report.totalDebit, report.totalCredit);
  const profit = await f.business.profitAndLoss(f.token, f.companyId, '2026-09-01', '2026-09-30');
  assert.equal(profit.netProfit, '10.10');
  const balance = await f.business.balanceSheet(f.token, f.companyId, '2026-09-27');
  assert.equal(balance.totalAssets, '10.61'); assert.equal(balance.totalLiabilities, '0.51');
  assert.equal(balance.totalEquity, '10.10');
  const other = await f.login('other');
  await assert.rejects(f.business.balanceSheet(other, f.companyId, '2026-09-27'), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(f.business.profitAndLoss(other, f.companyId, '2026-09-01', '2026-09-30'), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(f.business.trialBalance(other, f.companyId, '2026-09-27'), e => e.code === 'COMPANY_NOT_FOUND');
  await f.registry.transact(state => { state.companies[f.companyId].businessWrite = 'pending'; });
  await assert.rejects(f.business.trialBalance(f.token, f.companyId, '2026-09-27'), e => e.code === 'BUSINESS_WRITE_PENDING');
  await f.registry.transact(state => { delete state.companies[f.companyId].businessWrite; });
  const read = f.sheets.read;
  f.sheets.read = async (...args) => { const result = await read(...args); await f.service.logout(f.token); return result; };
  await assert.rejects(f.business.trialBalance(f.token, f.companyId, '2026-09-27'), e => e.code === 'UNAUTHORIZED');
});

function pay(f, table = 'Income', values = {}, version = 2, key = 'later_payment_key_01') {
  return f.business.sync(f.token, f.companyId, { operations: [{ operationId: key, table,
    action: 'pay', recordId: f.id, expectedVersion: version,
    values: { paidDate: '2026-10-01', account: 'Cash', reference: 'Payment', ...values } }] });
}

function reverse(f, table = 'Income', values = {}, version = 2, key = 'reverse_cash_key_001') {
  return f.business.sync(f.token, f.companyId, { operations: [{ operationId: key, table,
    action: 'reverse', recordId: f.id, expectedVersion: version,
    values: { date: '2026-10-01', description: 'Incorrect entry', ...values } }] });
}

test('unpaid reversal preserves history and negates each account without changing source fields', async () => {
  for (const table of ['Income', 'Expenses']) {
    const f = await cashFixture(table, false); await f.post();
    const original = structuredClone(f.data.Journals[0]), source = structuredClone(f.data[table][0]);
    f.data.FinancialPeriods.push({ companyId: f.companyId, startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
    assert.equal((await reverse(f, table)).results[0].status, 'APPLIED');
    assert.deepEqual(f.data.Journals[0], original);
    assert.equal(f.data.Journals[1].sourceType, `${table}Reversal`);
    assert.equal(f.data.Journals[1].date, '2026-10-01');
    for (const field of ['date', 'description', 'amount', 'total', 'paymentStatus']) assert.equal(f.data[table][0][field], source[field]);
    assert.equal((await f.business.list(f.token, f.companyId, table))[0].ledgerStatus, 'REVERSED');
    const balances = {};
    for (const line of f.data.JournalLines) balances[line.accountId] = (balances[line.accountId] || 0) + Math.round(line.debit * 100) - Math.round(line.credit * 100);
    assert.ok(Object.values(balances).every(n => n === 0));
    assert.equal((await reverse(f, table)).results[0].status, 'APPLIED');
    assert.equal((await reverse(f, table, {}, 3, 'duplicate_reverse_key')).results[0].error.code, 'REVERSAL_NOT_AVAILABLE');
    assert.equal((await pay(f, table, {}, 3)).results[0].error.code, 'PAYMENT_NOT_AVAILABLE');
    assert.equal(f.batchCount, 2);
  }
});

test('paid entry reversal refunds settlement and cancels accrual exactly once', async () => {
  for (const table of ['Income', 'Expenses']) {
    const f = await cashFixture(table); await f.post();
    assert.equal((await reverse(f, table)).results[0].status, 'APPLIED');
    assert.deepEqual(f.data.Journals.map(row => row.sourceType),
      [table, `${table}Payment`, `${table}Refund`, `${table}Reversal`]);
    const balances = {};
    for (const line of f.data.JournalLines) balances[line.accountId] = (balances[line.accountId] || 0) + Math.round(line.debit * 100) - Math.round(line.credit * 100);
    assert.ok(Object.values(balances).every(n => n === 0));
    assert.equal((await reverse(f, table, {}, 3, `paid_reverse_again_${table}`)).results[0].error.code, 'REVERSAL_NOT_AVAILABLE');
    assert.equal(f.batchCount, 2);
  }
});

test('reversals reject unposted entries and invalid or closed dates before any write', async () => {
  const f = await cashFixture('Income', false);
  assert.equal((await reverse(f, 'Income', {}, 1)).results[0].error.code, 'REVERSAL_NOT_AVAILABLE');
  await f.post();
  assert.equal((await reverse(f, 'Income', { date: '2026-09-01' })).results[0].error.code, 'INVALID_REVERSAL');
  assert.equal((await reverse(f, 'Income', { description: '' })).results[0].error.code, 'INVALID_REVERSAL');
  f.data.FinancialPeriods.push({ companyId: f.companyId, startDate: '2026-10-01', endDate: '2026-10-31', status: 'CLOSED' });
  assert.equal((await reverse(f)).results[0].error.code, 'PERIOD_CLOSED');
  assert.equal(f.batchCount, 1);
});

test('reversal retry after lost response cannot append a second reversal', async () => {
  const f = await cashFixture('Income', false); await f.post();
  const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { await write(...args); throw new Error('lost response'); };
  assert.equal((await reverse(f)).results[0].status, 'FAILED');
  assert.equal((await reverse(f)).results[0].status, 'APPLIED');
  assert.equal(f.batchCount, 2); assert.equal(f.data.Journals.length, 2);
});

test('later full payment settles posted unpaid entries without repeating accrual', async () => {
  for (const table of ['Income', 'Expenses']) {
    const f = await cashFixture(table, false); await f.post();
    const original = structuredClone(f.data.Journals[0]);
    f.data.FinancialPeriods.push({ companyId: f.companyId, startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
    assert.equal((await pay(f, table)).results[0].status, 'APPLIED');
    assert.deepEqual(f.data.Journals[0], original);
    assert.equal(f.data.Journals.length, 2);
    assert.equal(f.data.Journals[1].sourceType, `${table}Payment`);
    assert.equal(f.data.Journals[1].date, '2026-10-01');
    assert.equal(f.data[table][0].paymentStatus, 'PAID');
    assert.equal(f.data[table][0].recordVersion, 3);
    const lines = f.data.JournalLines.filter(l => l.journalId === f.data.Journals[1].recordId);
    assert.equal(lines.length, 2);
    assert.equal(lines.reduce((sum, l) => sum + l.debit, 0), 10.61);
    assert.equal(lines.reduce((sum, l) => sum + l.credit, 0), 10.61);
    await pay(f, table);
    assert.equal(f.batchCount, 2);
    assert.equal((await pay(f, table, {}, 3, 'duplicate_payment_key_1')).results[0].error.code, 'PAYMENT_NOT_AVAILABLE');
  }
});

test('later payment rejects unposted entries, changed amounts and closed payment dates', async () => {
  const unposted = await cashFixture('Income', false);
  assert.equal((await pay(unposted, 'Income', {}, 1)).results[0].error.code, 'PAYMENT_NOT_AVAILABLE');
  const f = await cashFixture('Income', false); await f.post();
  assert.equal((await pay(f, 'Income', { amount: 0.01 })).results[0].error.code, 'INVALID_PAYMENT');
  f.data.FinancialPeriods.push({ companyId: f.companyId, startDate: '2026-10-01', endDate: '2026-10-31', status: 'CLOSED' });
  assert.equal((await pay(f)).results[0].error.code, 'PERIOD_CLOSED');
  assert.equal(f.batchCount, 1);
  assert.equal(f.data.Income[0].paymentStatus, 'UNPAID');
});

test('lost later-payment response retries without a duplicate payment journal', async () => {
  const f = await cashFixture('Expenses', false); await f.post();
  const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { await write(...args); throw new Error('lost'); };
  assert.equal((await pay(f, 'Expenses')).results[0].status, 'FAILED');
  assert.equal((await pay(f, 'Expenses')).results[0].status, 'APPLIED');
  assert.equal(f.batchCount, 2); assert.equal(f.data.Journals.length, 2);
});

test('mismatched control balances and duplicate accruals cannot be settled', async () => {
  for (const change of ['control', 'duplicate', 'total']) {
    const f = await cashFixture('Income', false); await f.post();
    if (change === 'control') f.data.JournalLines[0].debit = 1;
    if (change === 'duplicate') f.data.Journals.push({ ...f.data.Journals[0], recordId: 'duplicate' });
    if (change === 'total') f.data.Income[0].total = 1;
    assert.equal((await pay(f)).results[0].error.code, 'PAYMENT_NOT_AVAILABLE');
    assert.equal(f.batchCount, 1);
  }
});

test('explicit cash posting writes balanced accrual and payment journals with source in one batch', async () => {
  for (const table of ['Income', 'Expenses']) {
    const f = await cashFixture(table);
    assert.equal((await f.post()).results[0].status, 'APPLIED');
    assert.equal(f.batchCount, 1);
    assert.equal(f.data[table][0].recordVersion, 2);
    assert.equal((await f.business.list(f.token, f.companyId, table))[0].ledgerStatus, 'LINKED');
    assert.equal(f.data.Journals.length, 2);
    assert.deepEqual(f.data.Journals.map(j => j.date), ['2026-09-26', '2026-09-27']);
    for (const journal of f.data.Journals) {
      assert.equal(journal.status, 'POSTED');
      const lines = f.data.JournalLines.filter(l => l.journalId === journal.recordId);
      const cents = field => lines.reduce((sum, l) => sum + Math.round(l[field] * 100), 0);
      assert.equal(cents('debit'), 1061); assert.equal(cents('credit'), 1061);
      assert.ok(lines.every(l => l.companyId === f.companyId));
    }
    assert.equal((await f.post()).results[0].status, 'APPLIED');
    assert.equal(f.batchCount, 1);
    assert.equal((await f.post('different_post_key_001')).results[0].error.code, 'VERSION_CONFLICT');
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, f.id, 'update',
      { expectedVersion: 2, values: { amount: 20 } }, 'posted_source_edit_001'), e => e.code === 'CASH_ENTRY_LINKED');
  }
});

test('unpaid entries post only accrual; closed payment periods reject the whole operation', async () => {
  const unpaid = await cashFixture('Expenses', false);
  assert.equal((await unpaid.post()).results[0].status, 'APPLIED');
  assert.equal(unpaid.data.Journals.length, 1);
  const paid = await cashFixture();
  paid.data.FinancialPeriods.push({ companyId: paid.companyId, startDate: '2026-09-27', endDate: '2026-09-27', status: 'CLOSED' });
  assert.equal((await paid.post()).results[0].error.code, 'PERIOD_CLOSED');
  assert.equal(paid.batchCount, 0);
  assert.equal(paid.data.Income[0].recordVersion, 1);
});

test('lost atomic posting response reconciles source marker without a second journal', async () => {
  const f = await cashFixture();
  const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { await write(...args); throw new Error('response lost'); };
  assert.equal((await f.post()).results[0].status, 'FAILED');
  assert.equal((await f.post()).results[0].status, 'APPLIED');
  assert.equal(f.batchCount, 1); assert.equal(f.data.Journals.length, 2);
});

test('posting rejects invalid payment details, forged values and unauthorized tenants', async () => {
  for (const change of [{ account: 'unknown' }, { paidDate: '2026-09-25' }]) {
    const f = await cashFixture(); Object.assign(f.data.Income[0], change);
    assert.equal((await f.post()).results[0].status, 'FAILED');
    assert.equal(f.batchCount, 0);
  }
  const f = await cashFixture(), other = await f.login('unrelated');
  await assert.rejects(f.business.mutate(other, f.companyId, 'Income', f.id, 'post',
    { expectedVersion: 1 }, 'foreign_post_key_001'), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(f.business.sync(f.token, f.companyId, { operations: [{ operationId: 'forged_post_values_1',
    table: 'Income', action: 'post', recordId: f.id, expectedVersion: 1, values: { total: 0 } }] }), e => e.code === 'INVALID_BATCH');
  assert.equal(f.batchCount, 0);
});

test('expense writes persist server totals and idempotent retries do not duplicate rows', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.Expenses = [];
  const input = { expectedVersion: 0, values: { date: '2026-09-26', description: 'Supplies',
    amount: 10.1, taxRate: 5, paymentStatus: 'UNPAID' } };
  const created = await f.business.mutate(f.token, f.companyId, 'Expenses', null, 'create', input, 'expense_create_policy_01');
  assert.equal(f.data.Expenses[0].taxAmount, 0.51);
  assert.equal(f.data.Expenses[0].total, 10.61);
  await f.business.mutate(f.token, f.companyId, 'Expenses', null, 'create', input, 'expense_create_policy_01');
  assert.equal(f.data.Expenses.length, 1);
  f.data.Journals = [{ companyId: f.companyId, sourceType: 'Expenses', sourceId: created.recordId, status: 'POSTED' }];
  for (const action of ['update', 'delete']) {
    await assert.rejects(f.business.mutate(f.token, f.companyId, 'Expenses', created.recordId, action,
      { expectedVersion: 1, ...(action === 'update' ? { values: { amount: 20 } } : {}) }, `expense_linked_${action}_01`),
    e => e.code === 'CASH_ENTRY_LINKED');
  }
  assert.equal(f.data.Expenses[0].recordVersion, 1);
  assert.equal((await f.registry.read()).state.companies[f.companyId].businessWrite, undefined);
  f.data.Journals = [];
  await f.business.mutate(f.token, f.companyId, 'Expenses', created.recordId, 'update',
    { expectedVersion: 1, values: { amount: 20 } }, 'expense_update_policy_01');
  assert.equal(f.data.Expenses[0].total, 21);
  assert.equal(f.data.Expenses[0].description, 'Supplies');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Expenses', created.recordId, 'update',
    { expectedVersion: 2, values: { total: 0 } }, 'expense_forged_policy_01'), e => e.code === 'CASH_TOTAL_MISMATCH');
  assert.equal(f.data.Expenses[0].recordVersion, 2);
  const state = (await f.registry.read()).state;
  assert.equal(state.companies[f.companyId].businessWrite, undefined);
});

test('seeded company profile is editable but cannot be duplicated or deleted', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.CompanyProfile = [{ recordId: 'company', companyId: f.companyId, recordVersion: 1, name: 'Before', _row: 2 }];
  const result = await f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update',
    { expectedVersion: 1, values: { name: 'After' } }, 'company_profile_update_1');
  assert.equal(result.version, 2); assert.equal(f.data.CompanyProfile[0].name, 'After');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', null, 'create',
    { expectedVersion: 0, values: { name: 'Duplicate' } }, 'company_profile_create_1'), e => e.code === 'COMPANY_PROFILE_SINGLETON');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'delete',
    { expectedVersion: 2 }, 'company_profile_delete_1'), e => e.code === 'COMPANY_PROFILE_SINGLETON');
});

test('document links require a completed upload bound to the same record', async () => {
  const f = await setup(), docId = 'd'.repeat(43);
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.CompanyProfile = [{ recordId: 'company', companyId: f.companyId, name: 'Business', recordVersion: 1, _row: 2 }];
  const input = { expectedVersion: 1, values: { logoDocumentId: docId } };
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update', input,
    'company_logo_update_001'), e => e.code === 'DOCUMENT_REFERENCE_INVALID');
  await f.registry.transact(state => { state.companies[f.companyId].documents = { [docId]: { status: 'READY', relatedSection: 'CompanyProfile', relatedRecordId: 'company' } }; });
  await f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update', input, 'company_logo_update_001');
  assert.equal(f.data.CompanyProfile[0].logoDocumentId, docId);
});

test('business create is tenant-bound, versioned and idempotent', async () => {
  const f = await setup(), key = 'customer_create_123456';
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }, key);
  assert.equal(created.version, 1); assert.equal(f.data.Customers.length, 1);
  const replay = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }, key);
  assert.deepEqual(replay, { ...created, replayed: true }); assert.equal(f.data.Customers.length, 1);
  const records = await f.business.list(f.token, f.companyId, 'Customers');
  assert.equal(records[0].name, 'A'); assert.ok(!Object.hasOwn(records[0], 'idempotencyKey'));
  const other = await f.login('owner-b');
  await assert.rejects(() => f.business.list(other, f.companyId, 'Customers'), error => error.code === 'COMPANY_NOT_FOUND');
});

test('business updates enforce expected versions and deletion is soft', async () => {
  const f = await setup();
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A' } }, 'customer_create_234567');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'update',
    { expectedVersion: 7, values: { name: 'wrong' } }, 'customer_update_wrong_1'), error => error.code === 'VERSION_CONFLICT');
  const updated = await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'update',
    { expectedVersion: 1, values: { name: 'B' } }, 'customer_update_234567');
  assert.equal(updated.version, 2); assert.equal(f.data.Customers[0].email ?? '', '');
  const removed = await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'delete',
    { expectedVersion: 2 }, 'customer_delete_234567');
  assert.equal(removed.version, 3); assert.equal((await f.business.list(f.token, f.companyId, 'Customers')).length, 0);
});

test('unknown write outcome reconciles marker without duplicate submission', async () => {
  const f = await setup(); let writes = 0;
  const normal = f.sheets.write;
  f.sheets.write = async (...args) => { writes++; await normal(...args); throw new Error('response lost'); };
  const input = { expectedVersion: 0, values: { name: 'A' } }, key = 'customer_uncertain_123';
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key));
  f.sheets.write = normal;
  const result = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key);
  assert.equal(result.replayed, true); assert.equal(writes, 1); assert.equal(f.data.Customers.length, 1);
});

test('batch retry replays completed operations and leaves later edits pending after a conflict', async () => {
  const f = await setup();
  const operations = [{ operationId: 'batch_customer_00001', table: 'Customers', action: 'create', expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }];
  const first = await f.business.sync(f.token, f.companyId, { operations });
  assert.equal(first.results[0].status, 'APPLIED');
  operations[0].values = { email: 'a@example.com', name: 'A' };
  assert.equal((await f.business.sync(f.token, f.companyId, { operations })).results[0].replayed, true);
  const conflict = { operationId: 'batch_customer_00002', table: 'Customers', recordId: first.results[0].recordId,
    action: 'update', expectedVersion: 9, values: { name: 'B' } };
  const next = { ...operations[0], operationId: 'batch_customer_00003' };
  const result = await f.business.sync(f.token, f.companyId, { operations: [conflict, next] });
  assert.equal(result.results[0].error.code, 'VERSION_CONFLICT');
  assert.equal(result.results[1].status, 'NOT_ATTEMPTED');
  assert.equal(f.data.Customers.length, 1);
});

test('batch validates all input before writing and rejects another tenant', async () => {
  const f = await setup(), op = { operationId: 'batch_customer_00001', table: 'Customers', action: 'create', expectedVersion: 0, values: { name: 'A' } };
  await assert.rejects(() => f.business.sync(f.token, f.companyId, { operations: [op, op] }), e => e.code === 'INVALID_BATCH');
  await assert.rejects(() => f.business.sync(f.token, f.companyId, { operations: [op, { ...op, operationId: 'batch_customer_00002', values: { companyId: 'wrong' } }] }), e => e.code === 'INVALID_RECORD');
  const other = await f.login('other');
  await assert.rejects(() => f.business.sync(other, f.companyId, { operations: [op] }), e => e.code === 'COMPANY_NOT_FOUND');
  assert.equal(f.data.Customers.length, 0);
});

test('a rejected competing request cannot clear a reserved write', async () => {
  const f = await setup(), read = f.sheets.read;
  let release, entered;
  const waiting = new Promise(resolve => { entered = resolve; });
  f.sheets.read = async (...args) => { entered(); await new Promise(resolve => { release = resolve; }); return read(...args); };
  const input = { expectedVersion: 0, values: { name: 'A' } }, key = 'reserved_customer_001';
  const writing = f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key);
  await waiting;
  const other = await f.login('other');
  await assert.rejects(() => f.business.mutate(other, f.companyId, 'Customers', null, 'create', input, key), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', { ...input, values: { name: 'B' } }, key), e => e.code === 'IDEMPOTENCY_CONFLICT');
  assert.ok(f.storage.state.companies[f.companyId].businessWrite);
  release(); await writing;
  assert.equal(f.data.Customers.length, 1);
});

test('sync downloads include minimal tombstones and recheck revoked sessions after Sheets reads', async () => {
  const f = await setup();
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'Private customer' } }, 'tombstone_create_001');
  await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'delete',
    { expectedVersion: 1 }, 'tombstone_delete_001');
  const rows = await f.business.list(f.token, f.companyId, 'Customers', { includeDeleted: true });
  assert.equal(rows.length, 1);
  assert.deepEqual(Object.keys(rows[0]).sort(), ['companyId', 'isDeleted', 'recordId', 'recordVersion', 'updatedAt']);
  assert.equal(rows[0].isDeleted, true);
  assert.equal(rows[0].recordVersion, 2);
  const read = f.sheets.read;
  f.sheets.read = async (...args) => { const result = await read(...args); await f.service.logout(f.token); return result; };
  await assert.rejects(() => f.business.list(f.token, f.companyId, 'Customers', { includeDeleted: true }), e => e.code === 'UNAUTHORIZED');
});

test('pending employee changes prevent business writes', async () => {
  const f = await setup();
  await f.registry.transact(state => { state.companies[f.companyId].employeeWrite = 'pending'; });
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A' } }, 'blocked_customer_001'), e => e.code === 'EMPLOYEE_UPDATE_PENDING');
  assert.equal(f.data.Customers.length, 0);
});

test('business fields reject system authority and unsupported tables', async () => {
  const f = await setup();
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { companyId: 'attacker', name: 'A' } }, 'customer_authority_12'), error => error.code === 'INVALID_RECORD');
  await assert.rejects(() => f.business.list(f.token, f.companyId, 'Roles'), error => error.code === 'TABLE_FORBIDDEN');
});
