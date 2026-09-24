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
    let submitted = false;
    try { return await this.workspace.withGoogle(companyId, async (token, company) => {
      const table = this.table(tableName), metadata = await this.google.metadata(token, company.resources.spreadsheetId);
      const sheet = metadata.sheets.find(item => item.properties.title === tableName)?.properties;
      requireThat(sheet && Number.isInteger(row) && row >= 2, 409, 'SCHEMA_MISMATCH', 'Business sheet is unavailable.');
      const requests = [];
      if (row > sheet.gridProperties.rowCount) requests.push({ updateSheetProperties: {
        properties: { sheetId: sheet.sheetId, gridProperties: { rowCount: row + 100 } }, fields: 'gridProperties.rowCount' } });
      for (const [key, value] of Object.entries(values)) {
        const column = table.headers.indexOf(key);
        requireThat(column >= 0 && ['string', 'number', 'boolean'].includes(typeof value),
          400, 'INVALID_FIELD', 'Invalid business field.');
        const userEnteredValue = typeof value === 'number' ? { numberValue: value } :
          typeof value === 'boolean' ? { boolValue: value } : { stringValue: value };
        requests.push({ updateCells: { start: { sheetId: sheet.sheetId, rowIndex: row - 1, columnIndex: column },
          rows: [{ values: [{ userEnteredValue }] }], fields: 'userEnteredValue' } });
      }
      submitted = true;
      await this.google.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(company.resources.spreadsheetId)}:batchUpdate`, 'POST', { requests });
    }); } catch (error) { if (!submitted) error.definitelyNotSubmitted = true; throw error; }
  }
}
