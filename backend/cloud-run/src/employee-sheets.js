import { TABLES } from './company-schema.js';
import { requireThat } from './errors.js';
export const ACCESS_TABLES = ['Employees', 'Roles', 'RolePermissions'];
export class EmployeeSheets {
  constructor(workspace, google) { this.workspace = workspace; this.google = google; }
  async read(companyId, names = ACCESS_TABLES) {
    const tables = names.map(name => {
      const table = TABLES.find(t => t.title === name);
      requireThat(table, 403, 'TABLE_FORBIDDEN', 'Table is unavailable.'); return table;
    });
    return this.workspace.withGoogle(companyId, async (token, company) => {
      const values = await this.google.rows(token, company.resources.spreadsheetId, tables.map(t => `'${t.title}'!A1:AZ10002`));
      return Object.fromEntries(tables.map((table, i) => {
        const [headers, ...rows] = values[i];
        requireThat(JSON.stringify(headers) === JSON.stringify(table.headers), 409, 'SCHEMA_MISMATCH', 'Company schema differs.');
        requireThat(rows.length <= 10000, 503, 'TABLE_CAPACITY', 'This table requires paginated access.');
        const seen = new Set();
        return [table.title, rows.flatMap((row, index) => {
          if (!row.length || row.every(v => v === '')) return [];
          const record = Object.fromEntries(table.headers.map((h, j) => [h, row[j] ?? '']));
          requireThat(record.recordId && record.companyId === companyId && !seen.has(record.recordId),
            409, 'RECORD_IDENTITY_MISMATCH', 'Company record identity differs.');
          seen.add(record.recordId); return [{ ...record, _row: index + 2 }];
        })];
      }));
    });
  }
  async write(companyId, changes) {
    let submitted = false;
    try { return await this.workspace.withGoogle(companyId, async (token, company) => {
      const metadata = await this.google.metadata(token, company.resources.spreadsheetId);
      const requests = [];
      for (const { table: name, row, values } of changes) {
        const table = TABLES.find(t => t.title === name), sheet = metadata.sheets.find(s => s.properties.title === name)?.properties;
        requireThat(table && sheet && Number.isInteger(row) && row >= 2, 409, 'SCHEMA_MISMATCH', 'Employee sheet is unavailable.');
        if (row > sheet.gridProperties.rowCount) {
          requests.push({ updateSheetProperties: { properties: { sheetId: sheet.sheetId, gridProperties: { rowCount: row + 100 } }, fields: 'gridProperties.rowCount' } });
        }
        for (const [key, value] of Object.entries(values)) {
          const column = table.headers.indexOf(key);
          requireThat(column >= 0 && ['string', 'number', 'boolean'].includes(typeof value), 400, 'INVALID_FIELD', 'Invalid employee field.');
          const userEnteredValue = typeof value === 'number' ? { numberValue: value } : typeof value === 'boolean' ? { boolValue: value } : { stringValue: value };
          requests.push({ updateCells: { start: { sheetId: sheet.sheetId, rowIndex: row - 1, columnIndex: column },
            rows: [{ values: [{ userEnteredValue }] }], fields: 'userEnteredValue' } });
        }
      }
      // All employee/role/permission changes apply in one Sheets batch. Each
      // operation reserves a single submission in control storage before this call.
      submitted = true;
      await this.google.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(company.resources.spreadsheetId)}:batchUpdate`, 'POST', { requests });
    }); } catch (error) {
      if (!submitted) error.definitelyNotSubmitted = true;
      throw error;
    }
  }
}
