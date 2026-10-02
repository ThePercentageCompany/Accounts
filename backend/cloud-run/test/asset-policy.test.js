import test from 'node:test';
import assert from 'node:assert/strict';
import { assetChanges } from '../src/asset-policy.js';

function fixture() {
  const data = { Assets: [], FinancialPeriods: [], Journals: [], JournalLines: [] };
  return { data, sheets: { read: async (_id, names) => Object.fromEntries(names.map(name => [name, data[name] || []])) } };
}
const system = { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' };
const draft = { companyId: 'c', recordId: 'a', assetCode: 'FA-1', name: 'Laptop', category: 'IT', purchaseDate: '2026-09-01',
  cost: 1200, usefulLife: 12, residualValue: 0, depreciationMethod: 'STRAIGHT_LINE', paymentAccount: 'Bank',
  accumulatedDepreciation: 0, netBookValue: 1200, lastDepreciationDate: '', status: 'DRAFT', acquisitionType: 'COMPANY_PURCHASE' };

test('asset draft derives book values and blocks duplicate codes', async () => {
  const f = fixture(), input = { assetCode: ' FA-1 ', name: ' Laptop ', category: 'IT', purchaseDate: '2026-09-01', cost: 1200,
    usefulLife: 12, residualValue: 0, depreciationMethod: 'STRAIGHT_LINE', paymentAccount: 'Bank', location: '', assignedEmployeeId: '', serialNumber: '', acquisitionType: 'COMPANY_PURCHASE' };
  const result = await assetChanges(f.sheets, 'c', 'Assets', 'a', 'create', null, input, system, 'op');
  assert.equal(result.values.netBookValue, 1200); assert.equal(result.values.status, 'DRAFT'); assert.equal(result.values.assetCode, 'FA-1');
  f.data.Assets.push(draft);
  await assert.rejects(assetChanges(f.sheets, 'c', 'Assets', 'b', 'create', null, { ...input, assetCode: 'fa-1' }, system, 'x'), e => e.code === 'ASSET_CODE_DUPLICATE');
});

test('capitalization posts balanced acquisition journal', async () => {
  const f = fixture(), result = await assetChanges(f.sheets, 'c', 'Assets', 'a', 'capitalize', draft, {}, system, 'cap');
  assert.equal(result.values.status, 'ACTIVE'); assert.equal(result.extra[1].values.accountId, 'fixed_assets');
  assert.equal(result.extra[2].values.accountId, 'bank'); assert.equal(result.extra[0].values.totalDebit, 1200);
});

test('monthly depreciation updates book value and cannot repeat a month', async () => {
  const f = fixture(), active = { ...draft, status: 'ACTIVE', acquisitionJournalId: 'j', lastDepreciationDate: '' };
  const result = await assetChanges(f.sheets, 'c', 'Assets', 'a', 'depreciate', active, { lastDepreciationDate: '2026-09-30' }, system, 'dep');
  assert.equal(result.values.accumulatedDepreciation, 100); assert.equal(result.values.netBookValue, 1100);
  assert.equal(result.extra[1].values.accountId, 'depreciation_expense');
  await assert.rejects(assetChanges(f.sheets, 'c', 'Assets', 'a', 'depreciate', { ...active, lastDepreciationDate: '2026-09-30' },
    { lastDepreciationDate: '2026-09-15' }, system, 'again'), e => e.code === 'ASSET_DEPRECIATION_DUPLICATE');
});

test('asset derived fields and unsupported acquisition types are rejected', async () => {
  const f = fixture();
  await assert.rejects(assetChanges(f.sheets, 'c', 'Assets', 'a', 'create', null, { netBookValue: 1 }, system, 'x'), e => e.code === 'ASSET_DERIVED_FIELD');
  const { accumulatedDepreciation, netBookValue, lastDepreciationDate, status, acquisitionJournalId, ...input } = draft;
  await assert.rejects(assetChanges(f.sheets, 'c', 'Assets', 'a', 'create', null, { ...input, acquisitionType: 'OPENING_BALANCE' }, system, 'x'), e => e.code === 'INVALID_ASSET');
});

test('asset disposal removes cost and depreciation and records gain or loss', async () => {
  const f = fixture(), active = { ...draft, status: 'ACTIVE', accumulatedDepreciation: 400, netBookValue: 800,
    lastDepreciationDate: '2026-08-31', acquisitionJournalId: 'j' };
  const result = await assetChanges(f.sheets, 'c', 'Assets', 'a', 'assetDispose', active,
    { disposalDate: '2026-09-30', disposalProceeds: 900, disposalAccount: 'Bank', disposalReason: 'Sold' }, system, 'dispose');
  assert.equal(result.values.status, 'DISPOSED'); assert.equal(result.values.netBookValue, 0);
  const lines = result.extra.slice(1).map(change => change.values);
  assert.equal(lines.find(line => line.accountId === 'bank').debit, 900);
  assert.equal(lines.find(line => line.accountId === 'accumulated_depreciation').debit, 400);
  assert.equal(lines.find(line => line.accountId === 'fixed_assets').credit, 1200);
  assert.equal(lines.find(line => line.accountId === 'gain_on_asset_disposal').credit, 100);
  assert.equal(lines.reduce((sum, line) => sum + line.debit, 0), lines.reduce((sum, line) => sum + line.credit, 0));

  const loss = await assetChanges(f.sheets, 'c', 'Assets', 'b', 'assetDispose', active,
    { disposalDate: '2026-09-30', disposalProceeds: 700, disposalAccount: 'Cash', disposalReason: 'Sold' }, system, 'loss');
  assert.equal(loss.extra.slice(1).find(change => change.values.accountId === 'loss_on_asset_disposal').values.debit, 100);
});
