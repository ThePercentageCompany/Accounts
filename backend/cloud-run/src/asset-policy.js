import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = cents => Number(cents) / 100;
const nextRow = rows => Math.max(1, ...rows.map(row => Number(row._row) || 1)) + 1;
const derived = new Set(['accumulatedDepreciation', 'netBookValue', 'lastDepreciationDate', 'disposalDate', 'disposalProceeds', 'disposalAccount', 'disposalReason', 'status', 'acquisitionJournalId']);

function journal(system, id, date, description, sourceType, sourceId, debit, credit, ledger) {
  const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
  return [
    { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: id,
      number: `AUTO-${id}`, date, description, sourceType, sourceId,
      totalDebit: money(debit.amount), totalCredit: money(credit.amount), status: 'POSTED' } },
    { table: 'JournalLines', row: nextRow(ledger.JournalLines), values: { ...meta,
      recordId: challenge(`${id}:0`), journalId: id, lineNumber: 1, ...debit, debit: money(debit.amount), credit: 0 } },
    { table: 'JournalLines', row: nextRow(ledger.JournalLines) + 1, values: { ...meta,
      recordId: challenge(`${id}:1`), journalId: id, lineNumber: 2, ...credit, debit: 0, credit: money(credit.amount) } },
  ].map(change => ({ ...change, values: Object.fromEntries(Object.entries(change.values).filter(([key]) => key !== 'amount')) }));
}

export async function assetChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (table !== 'Assets') return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'capitalize', 'depreciate', 'assetDispose'].includes(action), 400, 'INVALID_ASSET', 'Unsupported asset action.');
  requireThat(!old || old.status === 'DRAFT' || ['depreciate', 'assetDispose'].includes(action), 409, 'ASSET_LOCKED', 'Capitalized assets cannot be edited or deleted.');
  if (action === 'delete') return { values, extra: [] };
  if (action === 'capitalize') {
    requireThat(old?.status === 'DRAFT', 409, 'ASSET_NOT_CAPITALIZABLE', 'Only a draft asset can be capitalized.');
    await assertOpenLedgerDate(sheets, companyId, old.purchaseDate);
    const amount = minor(old.cost), ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const journalId = challenge(`${companyId}:${operation}:asset-acquisition`);
    const creditId = old.paymentAccount === 'Cash' ? 'cash' : 'bank';
    return { values: { status: 'ACTIVE', acquisitionJournalId: journalId }, extra: journal(system, journalId,
      old.purchaseDate, `Asset acquisition ${old.assetCode}`, 'AssetAcquisition', id,
      { accountId: 'fixed_assets', accountName: 'Fixed Assets', accountGroup: 'Asset', amount },
      { accountId: creditId, accountName: old.paymentAccount, accountGroup: 'Asset', amount }, ledger) };
  }
  if (action === 'depreciate') {
    requireThat(old?.status === 'ACTIVE' && Object.keys(values).length === 1 && validLedgerDate(values.lastDepreciationDate),
      409, 'ASSET_NOT_DEPRECIABLE', 'Choose a valid depreciation date for an active asset.');
    const date = values.lastDepreciationDate;
    requireThat(date >= old.purchaseDate && (!old.lastDepreciationDate || date.slice(0, 7) > old.lastDepreciationDate.slice(0, 7)),
      409, 'ASSET_DEPRECIATION_DUPLICATE', 'Depreciation must be after acquisition and after the last posted month.');
    await assertOpenLedgerDate(sheets, companyId, date);
    const cost = minor(old.cost), residual = minor(old.residualValue), accumulated = minor(old.accumulatedDepreciation);
    const remaining = cost - residual - accumulated;
    requireThat(remaining > 0n, 409, 'ASSET_FULLY_DEPRECIATED', 'This asset is already fully depreciated.');
    const monthly = (cost - residual + BigInt(old.usefulLife) / 2n) / BigInt(old.usefulLife);
    const amount = monthly < remaining ? monthly : remaining;
    const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const journalId = challenge(`${companyId}:${operation}:asset-depreciation`), nextAccumulated = accumulated + amount;
    return { values: { accumulatedDepreciation: money(nextAccumulated), netBookValue: money(cost - nextAccumulated),
      lastDepreciationDate: date }, extra: journal(system, journalId, date, `Depreciation ${old.assetCode}`,
      'AssetDepreciation', id,
      { accountId: 'depreciation_expense', accountName: 'Depreciation Expense', accountGroup: 'Expense', amount },
      { accountId: 'accumulated_depreciation', accountName: 'Accumulated Depreciation', accountGroup: 'Asset', amount }, ledger) };
  }
  if (action === 'assetDispose') {
    requireThat(old?.status === 'ACTIVE' && Object.keys(values).every(key =>
      ['disposalDate', 'disposalProceeds', 'disposalAccount', 'disposalReason'].includes(key)) &&
      validLedgerDate(values.disposalDate) && values.disposalDate >= old.purchaseDate &&
      (!old.lastDepreciationDate || values.disposalDate >= old.lastDepreciationDate) &&
      ['Cash', 'Bank'].includes(values.disposalAccount) && typeof values.disposalReason === 'string' &&
      values.disposalReason.trim().length > 0 && values.disposalReason.length <= 500,
    409, 'ASSET_NOT_DISPOSABLE', 'Choose a valid disposal date, proceeds account and reason for an active asset.');
    await assertOpenLedgerDate(sheets, companyId, values.disposalDate);
    const cost = minor(old.cost), accumulated = minor(old.accumulatedDepreciation), proceeds = minor(values.disposalProceeds);
    requireThat(accumulated <= cost, 409, 'ASSET_BOOK_VALUE_INVALID', 'Asset depreciation exceeds its cost.');
    const bookValue = cost - accumulated, gain = proceeds > bookValue ? proceeds - bookValue : 0n;
    const loss = bookValue > proceeds ? bookValue - proceeds : 0n;
    const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const journalId = challenge(`${companyId}:${operation}:asset-disposal`);
    const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    const lines = [
      ...(proceeds > 0n ? [{ accountId: values.disposalAccount === 'Cash' ? 'cash' : 'bank', accountName: values.disposalAccount,
        accountGroup: 'Asset', debit: money(proceeds), credit: 0 }] : []),
      ...(accumulated > 0n ? [{ accountId: 'accumulated_depreciation', accountName: 'Accumulated Depreciation',
        accountGroup: 'Asset', debit: money(accumulated), credit: 0 }] : []),
      ...(loss > 0n ? [{ accountId: 'loss_on_asset_disposal', accountName: 'Loss on Asset Disposal',
        accountGroup: 'Expense', debit: money(loss), credit: 0 }] : []),
      { accountId: 'fixed_assets', accountName: 'Fixed Assets', accountGroup: 'Asset', debit: 0, credit: money(cost) },
      ...(gain > 0n ? [{ accountId: 'gain_on_asset_disposal', accountName: 'Gain on Asset Disposal',
        accountGroup: 'Income', debit: 0, credit: money(gain) }] : []),
    ];
    return { values: { disposalDate: values.disposalDate, disposalProceeds: money(proceeds),
      disposalAccount: values.disposalAccount, disposalReason: values.disposalReason.trim(), netBookValue: 0, status: 'DISPOSED' }, extra: [
      { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: journalId, number: `AUTO-${journalId}`,
        date: values.disposalDate, description: `Asset disposal ${old.assetCode}: ${values.disposalReason.trim()}`,
        sourceType: 'AssetDisposal', sourceId: id, totalDebit: money(cost + gain), totalCredit: money(cost + gain), status: 'POSTED' } },
      ...lines.map((line, index) => ({ table: 'JournalLines', row: nextRow(ledger.JournalLines) + index,
        values: { ...meta, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1, ...line } })),
    ] };
  }
  requireThat(!Object.keys(values).some(key => derived.has(key)), 400, 'ASSET_DERIVED_FIELD', 'Asset book values and status are assigned by the server.');
  const next = { ...old, ...values };
  requireThat(typeof next.assetCode === 'string' && next.assetCode.trim().length > 0 && typeof next.name === 'string' && next.name.trim().length > 0 &&
    validLedgerDate(next.purchaseDate) && minor(next.cost) > 0n && Number.isSafeInteger(next.usefulLife) && next.usefulLife > 0 && next.usefulLife <= 1200 &&
    minor(next.residualValue) >= 0n && minor(next.residualValue) <= minor(next.cost) && next.depreciationMethod === 'STRAIGHT_LINE' &&
    ['Cash', 'Bank'].includes(next.paymentAccount) && next.acquisitionType === 'COMPANY_PURCHASE',
  400, 'INVALID_ASSET', 'Supply a code, name, date, cost, residual value, useful life, straight-line method and payment account.');
  const all = await sheets.read(companyId, ['Assets']);
  requireThat(!all.Assets.some(row => row.companyId === companyId && row.recordId !== id && active(row) &&
    String(row.assetCode).toUpperCase() === next.assetCode.trim().toUpperCase()), 409, 'ASSET_CODE_DUPLICATE', 'Asset code already exists.');
  return { values: { ...values, assetCode: next.assetCode.trim(), name: next.name.trim(), acquisitionType: 'COMPANY_PURCHASE',
    depreciationMethod: 'STRAIGHT_LINE', accumulatedDepreciation: 0, netBookValue: money(minor(next.cost)),
    lastDepreciationDate: '', disposalDate: '', disposalProceeds: 0, disposalAccount: '', disposalReason: '',
    status: 'DRAFT', acquisitionJournalId: '' }, extra: [] };
}
