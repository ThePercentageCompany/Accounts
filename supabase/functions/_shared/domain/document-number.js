import { requireThat } from './errors.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';

// Yearly document numbers share one scan-max+1 algorithm: PREFIX-YYYY-NNNNNN
// per company, gaps allowed, sequences never reused. Called under the existing
// workspace business-write lock, so concurrent writes cannot race.
export async function nextDocumentNumber(records, companyId, table, prefix, date, errorCode, message) {
  const data = await records.read(companyId, [table]);
  const year = String(date).slice(0, 4);
  const pattern = new RegExp(`^${prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}-${year}-(\\d{6})$`);
  const sequence = Math.max(0, ...data[table].filter(row => row.companyId === companyId && active(row))
    .map(row => pattern.exec(row.number ?? '')?.[1]).filter(Boolean).map(Number)) + 1;
  requireThat(sequence <= 999999, 409, errorCode, message);
  return `${prefix}-${year}-${String(sequence).padStart(6, '0')}`;
}
