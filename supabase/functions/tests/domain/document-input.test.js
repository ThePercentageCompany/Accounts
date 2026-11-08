import test from 'node:test';
import assert from 'node:assert/strict';
import { BusinessService } from '../../_shared/domain/business-service.js';
import { TABLES } from '../../_shared/domain/company-schema.js';

const service = new BusinessService({
  accounts: {},
  records: { table: name => TABLES.find(table => table.title === name) },
});

for (const table of ['Invoices', 'Quotations']) {
  test(`${table} accepts the editor's complete cash customer draft`, () => {
    const draft = {
      customerId: '', cashCustomerName: 'Walk-in customer',
      issueDate: '2026-11-08',
      [table === 'Invoices' ? 'dueDate' : 'validUntil']: '2026-12-08',
      currency: 'AED', baseCurrency: 'AED', exchangeRate: 1,
      rateDate: '2026-11-08', rateSource: 'BASE', notes: '', paymentTerms: '',
      items: [{ description: 'Service', quantity: 1, unitPrice: 100, discount: 0, taxRate: 5 }],
    };
    assert.deepEqual(service.values(table, draft), draft);
    assert.throws(() => service.values(table, { ...draft, unsupported: true }),
      error => error.code === 'INVALID_RECORD');
  });
}
