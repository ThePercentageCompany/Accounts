import { ApiError, requireThat } from './errors.js';
import { ReconnectRequired } from './google-connection.js';
import { TABLES, seedRows } from './company-schema.js';

export const FOLDER_MIME = 'application/vnd.google-apps.folder';
export const SHEET_MIME = 'application/vnd.google-apps.spreadsheet';
const FILE_FIELDS = 'id,name,mimeType,parents,appProperties,trashed,ownedByMe';
export class GoogleRequestError extends ApiError {
  constructor(status) { super(503, 'GOOGLE_REQUEST_FAILED', 'Google request failed. Retry setup.'); this.googleStatus = status; }
}
export class GoogleWorkspace {
  constructor({ fetcher = fetch } = {}) { this.fetcher = fetcher; }
  async request(token, url, method = 'GET', data) {
    const response = await this.fetcher(url, { method, redirect: 'error', signal: AbortSignal.timeout(20_000),
      headers: { Authorization: `Bearer ${token}`, ...(data ? { 'Content-Type': 'application/json' } : {}) },
      ...(data ? { body: JSON.stringify(data) } : {}) });
    if (response.status === 401) { const error = new ReconnectRequired(); error.definitelyRejected = true; throw error; }
    if (response.status === 403) {
      const denied = await response.json().catch(() => ({}));
      const reasons = [...(denied.error?.errors || []), ...(denied.error?.details || [])].map(e => e.reason);
      if (reasons.includes('insufficientPermissions') || reasons.includes('ACCESS_TOKEN_SCOPE_INSUFFICIENT')) {
        const error = new ReconnectRequired(); error.definitelyRejected = true; throw error;
      }
    }
    if (!response.ok) throw new GoogleRequestError(response.status);
    return response.status === 204 ? {} : response.json();
  }
  async generateFolderIds(token, count) {
    const result = await this.request(token, `https://www.googleapis.com/drive/v3/files/generateIds?count=${count}&space=drive&type=files`);
    requireThat(Array.isArray(result.ids) && result.ids.length === count && new Set(result.ids).size === count &&
      result.ids.every(id => typeof id === 'string' && /^[A-Za-z0-9_-]+$/.test(id)),
    503, 'GOOGLE_RESPONSE_INVALID', 'Google did not return valid resource identifiers.');
    return result.ids;
  }
  async file(token, id) {
    try { return await this.request(token, `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?fields=${FILE_FIELDS}`); }
    catch (error) { if (error.googleStatus === 404) return null; throw error; }
  }
  validateFile(file, companyId, operation, mime, parent) {
    requireThat(file && typeof file.id === 'string' && /^[A-Za-z0-9_-]+$/.test(file.id) &&
      !file.trashed && file.ownedByMe === true && file.mimeType === mime &&
      file.appProperties?.tpcCompany === companyId && file.appProperties?.tpcOperation === operation &&
      (!parent || (file.parents?.length === 1 && file.parents[0] === parent)),
    409, 'RESOURCE_MISMATCH', 'An existing workspace resource is missing or changed. Setup will not replace it.');
    return file;
  }
  async createFile(token, { id, name, mimeType, companyId, operation, parent }) {
    return this.request(token, `https://www.googleapis.com/drive/v3/files?fields=${FILE_FIELDS}`, 'POST', {
      ...(id ? { id } : {}), name, mimeType, ...(parent ? { parents: [parent] } : {}),
      appProperties: { tpcCompany: companyId, tpcOperation: operation },
    });
  }
  async ensureFolder(token, spec) {
    let file = await this.file(token, spec.id);
    if (!file) {
      try { file = await this.createFile(token, { ...spec, mimeType: FOLDER_MIME }); }
      catch (error) {
        if (error.googleStatus !== 409) throw error;
        file = await this.file(token, spec.id);
      }
    }
    requireThat(file?.id === spec.id, 409, 'RESOURCE_MISMATCH', 'Google folder identity differs from the saved setup operation.');
    return this.validateFile(file, spec.companyId, spec.operation, FOLDER_MIME, spec.parent);
  }
  async findSpreadsheet(token, companyId, operation) {
    // Both identifiers originate inside the backend; never interpolate customer names.
    const quote = value => value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    const q = `appProperties has { key='tpcCompany' and value='${quote(companyId)}' } and appProperties has { key='tpcOperation' and value='${quote(operation)}' }`;
    const query = new URLSearchParams({ q, fields: `files(${FILE_FIELDS}),nextPageToken,incompleteSearch`, pageSize: '100', spaces: 'drive' });
    const result = await this.request(token, `https://www.googleapis.com/drive/v3/files?${query}`);
    requireThat(Array.isArray(result.files) && !result.nextPageToken && !result.incompleteSearch && result.files.length <= 1,
      409, 'RESOURCE_AMBIGUOUS', 'Workspace resource lookup needs review. No replacement was created.');
    return result.files[0] || null;
  }
  async metadata(token, id) {
    return this.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(id)}?fields=sheets.properties`);
  }
  async rows(token, id, ranges) {
    const query = new URLSearchParams({ valueRenderOption: 'UNFORMATTED_VALUE' });
    for (const range of ranges) query.append('ranges', range);
    const result = await this.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(id)}/values:batchGet?${query}`);
    requireThat(Array.isArray(result.valueRanges) && result.valueRanges.length === ranges.length,
      503, 'GOOGLE_RESPONSE_INVALID', 'Google returned incomplete spreadsheet data.');
    return result.valueRanges.map(r => r.values || []);
  }
  async ensureSchema(token, company, owner) {
    const id = company.resources.spreadsheetId, metadata = await this.metadata(token, id);
    const properties = metadata.sheets.map(s => s.properties);
    const missing = TABLES.filter(t => !properties.some(p => p.title === t.title));
    for (const table of missing) requireThat(!properties.some(p => p.sheetId === table.sheetId),
      409, 'SCHEMA_MISMATCH', 'A reserved sheet identifier is already in use.');
    if (missing.length) await this.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(id)}:batchUpdate`, 'POST', {
      requests: missing.map(t => ({ addSheet: { properties: { title: t.title, sheetId: t.sheetId,
        gridProperties: { rowCount: 1000, columnCount: t.headers.length, frozenRowCount: 1 } } } })),
    });
    const headerRows = await this.rows(token, id, TABLES.map(t => `'${t.title}'!1:1`));
    const data = [];
    TABLES.forEach((table, i) => {
      const row = headerRows[i][0] || [];
      requireThat(!row.length || JSON.stringify(row) === JSON.stringify(table.headers),
        409, 'SCHEMA_MISMATCH', 'Existing spreadsheet headers differ. No migration was attempted.');
      if (!row.length) data.push({ range: `'${table.title}'!A1`, values: [table.headers] });
    });
    const seeds = seedRows(company, owner);
    const existing = await this.rows(token, id, seeds.map(s => `'${s.title}'!2:2`));
    seeds.forEach((seed, i) => {
      const row = existing[i][0] || [];
      requireThat(!row.length || (row[0] === seed.values[0] && row[1] === company.id),
        409, 'SCHEMA_MISMATCH', 'Company identity row differs. Setup will not overwrite it.');
      if (!row.length) data.push({ range: `'${seed.title}'!A2`, values: [seed.values] });
    });
    if (data.length) await this.request(token, `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(id)}/values:batchUpdate`,
      'POST', { valueInputOption: 'RAW', data });
  }
  async verifySchema(token, company) {
    const id = company.resources.spreadsheetId;
    const rows = await this.rows(token, id, TABLES.map(t => `'${t.title}'!1:1`));
    TABLES.forEach((t, i) => requireThat(JSON.stringify(rows[i][0]) === JSON.stringify(t.headers),
      409, 'SCHEMA_MISMATCH', 'Spreadsheet schema verification failed.'));
    const identities = await this.rows(token, id, ["'SystemConfiguration'!A2:L2", "'CompanyProfile'!A2:B2", "'OwnersUsers'!A2:B2"]);
    requireThat(identities.every(rows => rows[0]?.[1] === company.id) && identities[0][0][10] === 'schemaVersion' &&
      Number(identities[0][0][11]) === 1, 409, 'SCHEMA_MISMATCH', 'Workspace identity verification failed.');
  }
}
