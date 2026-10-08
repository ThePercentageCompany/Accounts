import { TABLES } from './company-schema.js';
import { requireThat } from './errors.js';

const BLOCKED = new Set(['SystemConfiguration', 'OwnersUsers', 'Roles', 'RolePermissions',
  'Employees', 'EmployeeAccess', 'DocumentRegistry', 'SyncOperations', 'AuditLog', 'NumberSequences']);
export const BUSINESS_TABLES = Object.freeze(TABLES.filter(t => !BLOCKED.has(t.title)).map(t => t.title));

export class BusinessSheets {
  constructor(workspace, google) { Object.assign(this, { workspace, google }); }
  table(name) {
    requireThat(BUSINESS_TABLES.includes(name), 403, 'TABLE_FORBIDDEN', 'This business table is unavailable.');
    return TABLES.find(t => t.title === name);
  }
  async read(companyId, names) {
    return this.readTables(companyId, names.map(name => this.table(name)));
  }
  async readReferences(companyId, names) {
    return this.readTables(companyId, names.map(name => name === 'Employees' ? TABLES.find(t => t.title === name) : this.table(name)));
  }
  async readTables(companyId, tables) {
    return this.workspace.withGoogle(companyId, async (token, company) => {
      if (tables.some(t => ['CreditNotes', 'CreditNoteItems'].includes(t.title))) {
        await this.google.ensureCreditTables(token, company.resources.spreadsheetId);
      }
      if (tables.some(t => ['Tasks', 'TaskComments', 'TaskActivity'].includes(t.title))) {
        await this.google.ensureTaskTables(token, company.resources.spreadsheetId);
      }
      if (tables.some(t => t.title === 'Projects')) await this.google.ensureTables(token, company.resources.spreadsheetId, ['Projects']);
      const values = await this.google.rows(token, company.resources.spreadsheetId,
        tables.map(t => `'${t.title}'!A1:AZ10002`));
      return Object.fromEntries(tables.map((table, i) => {
        const [headers = [], ...rows] = values[i] || [];
        requireThat(JSON.stringify(headers) === JSON.stringify(table.headers), 409, 'SCHEMA_MISMATCH', 'Company schema differs.');
        requireThat(rows.length <= 10000, 503, 'TABLE_CAPACITY', 'This table requires paginated access.');
        const seen = new Set();
        return [table.title, rows.flatMap((row, index) => {
          if (!row.length || row.every(value => value === '')) return [];
          const record = Object.fromEntries(table.headers.map((header, column) => [header, row[column] ?? '']));
          requireThat(record.recordId && record.companyId === companyId && !seen.has(record.recordId),
            409, 'RECORD_IDENTITY_MISMATCH', 'Company record identity differs.');
          seen.add(record.recordId); return [{ ...record, _row: index + 2 }];
        })];
      }));
    });
  }
  async write(companyId, tableName, row, values) {
    return this.writeBatch(companyId, [{ table: tableName, row, values }]);
  }
  // Internal transport primitive. The caller must hold the company write
  // reservation and validate business rules before submitting these changes.
  async writeBatch(companyId, changes) {
    let submitted = false;
    try {
      requireThat(Array.isArray(changes) && changes.length > 0 && changes.length <= 250,
        400, 'INVALID_BATCH', 'Supply between 1 and 250 internal record writes.');
      const seen = new Set();
      const prepared = changes.map(change => {
        requireThat(change && Number.isSafeInteger(change.row) && change.row >= 2 && change.row <= 10001 &&
          change.values && typeof change.values === 'object' && !Array.isArray(change.values) &&
          Object.keys(change.values).length > 0, 400, 'INVALID_RECORD', 'Invalid business row write.');
        const table = this.table(change.table), target = `${change.table}:${change.row}`;
        requireThat(!seen.has(target), 400, 'INVALID_BATCH', 'A batch cannot write a row twice.');
        seen.add(target);
        requireThat(!Object.hasOwn(change.values, 'companyId') || change.values.companyId === companyId,
          409, 'RECORD_IDENTITY_MISMATCH', 'Company record identity differs.');
        for (const [key, value] of Object.entries(change.values)) {
          requireThat(table.headers.includes(key) && ['string', 'number', 'boolean'].includes(typeof value) &&
            (typeof value !== 'number' || Number.isFinite(value)) &&
            (typeof value !== 'string' || value.length <= 10000), 400, 'INVALID_FIELD', 'Invalid business field.');
        }
        return { ...change, values: { ...change.values }, schema: table };
      });
      return await this.workspace.withGoogle(companyId, async (token, company) => {
      const metadata = await this.google.metadata(token, company.resources.spreadsheetId);
      const requests = [], growth = new Map();
      for (const { table: tableName, row, values, schema: table } of prepared) {
        const sheet = metadata.sheets.find(item => item.properties.title === tableName)?.properties;
        requireThat(sheet && Number.isSafeInteger(sheet.gridProperties?.rowCount),
          409, 'SCHEMA_MISMATCH', 'Business sheet is unavailable.');
        if (row > sheet.gridProperties.rowCount) growth.set(sheet.sheetId,
          Math.max(growth.get(sheet.sheetId) || 0, row + 100));
        for (const [key, value] of Object.entries(values)) {
        const column = table.headers.indexOf(key);
        const userEnteredValue = typeof value === 'number' ? { numberValue: value } :
          typeof value === 'boolean' ? { boolValue: value } : { stringValue: value };
        requests.push({ updateCells: { start: { sheetId: sheet.sheetId, rowIndex: row - 1, columnIndex: column },
          rows: [{ values: [{ userEnteredValue }] }], fields: 'userEnteredValue' } });
        }
      }
      requests.unshift(...[...growth].map(([sheetId, rowCount]) => ({ updateSheetProperties: {
        properties: { sheetId, gridProperties: { rowCount } }, fields: 'gridProperties.rowCount' } })));
      submitted = true;
      await this.google.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(company.resources.spreadsheetId)}:batchUpdate`, 'POST', { requests });
    }); } catch (error) { if (!submitted) error.definitelyNotSubmitted = true; throw error; }
  }
}
