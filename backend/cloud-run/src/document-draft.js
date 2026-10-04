import { requireThat } from './errors.js';
import { validateBusinessValues } from './business-values.js';
import { challenge } from './crypto.js';

export function draftItems(items) {
  requireThat(Array.isArray(items) && items.length > 0 && items.length <= 100,
    400, 'INVALID_DOCUMENT_ITEMS', 'Supply between 1 and 100 document lines.');
  return items.map((item, index) => {
    requireThat(item && typeof item === 'object' && !Array.isArray(item) &&
      Object.keys(item).every(key => ['description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'productId'].includes(key)),
    400, 'INVALID_DOCUMENT_ITEMS', 'Supply only description, quantity, unit price, discount, tax rate and an optional product reference.');
    const line = { discount: 0, taxRate: 0, ...item, lineNumber: index + 1 };
    requireThat(typeof line.description === 'string' && line.description.trim().length > 0 &&
      line.description.length <= 1000, 400, 'INVALID_DOCUMENT_ITEMS', 'Line descriptions must contain 1 to 1000 characters.');
    requireThat(!line.productId || (typeof line.productId === 'string' && /^[A-Za-z0-9_-]{43}$/.test(line.productId)),
      400, 'INVALID_DOCUMENT_ITEMS', 'Invalid product reference.');
    validateBusinessValues(line);
    return line;
  });
}

/// All changes join the existing Sheets atomic batch and idempotency marker.
/// Replacing draft lines also advances the header version, so an editor loaded
/// before a separate line edit cannot overwrite that edit.
export function replaceDraftItems(companyId, table, parentField, parentId,
  existing, items, system, operation, calculate) {
  const money = value => Number(value) / 100;
  const firstRow = Math.max(1, ...existing.map(row => Number(row._row) || 1)) + 1;
  const lines = draftItems(items).map(item => {
    const amount = calculate(item);
    return { ...item, taxAmount: money(amount.tax), lineTotal: money(amount.total) };
  });
  const extra = [
    ...existing.filter(row => row.companyId === companyId && row[parentField] === parentId &&
      row.isDeleted !== true && row.isDeleted !== 'TRUE').map(row => ({ table, row: row._row, values: {
      updatedAt: system.updatedAt, updatedBy: system.updatedBy,
      recordVersion: Number(row.recordVersion) + 1, isDeleted: true, idempotencyKey: system.idempotencyKey,
    } })),
    ...lines.map((line, index) => ({ table, row: firstRow + index, values: {
      ...system, recordId: challenge(`${companyId}:${operation}:draft-line:${index}`),
      recordVersion: 1, createdAt: system.updatedAt, createdBy: system.updatedBy,
      ...line, [parentField]: parentId,
    } })),
  ];
  requireThat(extra.length < 250, 400, 'INVALID_DOCUMENT_ITEMS',
    'This draft has too many existing lines for complete replacement. Edit its lines individually.');
  return { lines, extra };
}
