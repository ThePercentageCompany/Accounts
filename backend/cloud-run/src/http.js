import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { ApiError, requireThat } from './errors.js';

const SESSION = '__Host-tpc_session';
const OAUTH = '__Host-tpc_oauth';
const cookie = (name, value, seconds, sameSite = 'None') =>
  `${name}=${value}; Path=/; HttpOnly; Secure; SameSite=${sameSite}; Max-Age=${seconds}`;
function cookies(request) {
  const result = Object.create(null);
  for (const item of (request.headers.cookie || '').split(';')) {
    const index = item.indexOf('=');
    if (index > 0) {
      const key = item.slice(0, index).trim();
      requireThat(!(key in result), 400, 'INVALID_COOKIE', 'Duplicate cookies are not accepted.');
      result[key] = item.slice(index + 1).trim();
    }
  }
  return result;
}
async function body(request) {
  requireThat(request.headers['content-type']?.split(';')[0].trim() === 'application/json',
    415, 'JSON_REQUIRED', 'Use application/json.');
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    requireThat(size <= 16 * 1024, 413, 'BODY_TOO_LARGE', 'Request is too large.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new ApiError(400, 'INVALID_JSON', 'Invalid JSON body.'); }
}

export function createApi(service, config, { log = console.error } = {}) {
  const server = createServer(async (request, response) => {
    const requestId = randomUUID();
    response.setHeader('X-Request-Id', requestId);
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
    response.setHeader('Strict-Transport-Security', 'max-age=31536000');
    response.setHeader('Vary', 'Origin');
    const json = (status, value) => {
      response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify(value));
    };
    try {
      const origin = request.headers.origin;
      if (origin !== undefined) {
        requireThat(origin === config.appOrigin, 403, 'ORIGIN_DENIED', 'Request origin is not allowed.');
        response.setHeader('Access-Control-Allow-Origin', config.appOrigin);
        response.setHeader('Access-Control-Allow-Credentials', 'true');
      }
      if (request.method === 'OPTIONS') {
        requireThat(origin === config.appOrigin, 403, 'ORIGIN_DENIED', 'Request origin is not allowed.');
        response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Idempotency-Key, X-TPC-CSRF');
        response.writeHead(204); response.end(); return;
      }
      const url = new URL(request.url, config.apiOrigin);
      if (request.method === 'GET' && url.pathname === '/healthz') {
        json(200, { status: 'ok', phase: 1 }); return;
      }
      // Every browser mutation requires an exact allowed Origin and a non-simple
      // header. Cookies alone cannot authorize cross-site form submissions.
      if (request.method !== 'GET') {
        requireThat(origin === config.appOrigin && request.headers['x-tpc-csrf'] === '1',
          403, 'CSRF_REJECTED', 'Request verification failed.');
      }
      const jar = cookies(request), token = jar[SESSION];
      const route = `${request.method} ${url.pathname}`;
      if (route === 'POST /v1/auth/google/start') {
        await body(request);
        const result = await service.startSignIn(jar[OAUTH]);
        response.setHeader('Set-Cookie', cookie(OAUTH, result.binding, config.oauthMs / 1000, 'Lax'));
        json(200, { authorizationUrl: result.authorizationUrl }); return;
      }
      if (route === 'GET /v1/auth/google/callback') {
        // Fixed post-login destination; never honor a client-supplied return URL.
        const result = await service.finishSignIn(url.searchParams.get('state'), jar[OAUTH],
          url.searchParams.get('code'), token);
        response.setHeader('Set-Cookie', [cookie(SESSION, result.token, config.sessionMs / 1000), cookie(OAUTH, '', 0, 'Lax')]);
        response.writeHead(303, { Location: `${config.appOrigin}/` }); response.end(); return;
      }
      if (route === 'GET /v1/me') { json(200, { owner: await service.me(token) }); return; }
      if (route === 'POST /v1/auth/logout' || route === 'POST /v1/auth/revoke-sessions') {
        await body(request);
        await service.logout(token, route.endsWith('revoke-sessions'));
        response.setHeader('Set-Cookie', cookie(SESSION, '', 0));
        response.writeHead(204); response.end(); return;
      }
      if (route === 'GET /v1/companies') { json(200, { companies: await service.listCompanies(token) }); return; }
      if (route === 'POST /v1/companies') {
        const result = await service.createCompany(token, await body(request), request.headers['idempotency-key']);
        json(result.replayed ? 200 : 201, result); return;
      }
      const statusMatch = /^\/v1\/companies\/([A-Za-z0-9_-]{43})\/setup$/.exec(url.pathname);
      if (request.method === 'GET' && statusMatch) {
        json(200, { company: await service.companyStatus(token, statusMatch[1]) }); return;
      }
      throw new ApiError(404, 'NOT_FOUND', 'Endpoint not found.');
    } catch (error) {
      // Never log URLs, cookies, OAuth codes, request bodies, or Google error payloads.
      if (!(error instanceof ApiError)) log(JSON.stringify({ requestId, event: 'request_failed' }));
      if (!response.headersSent) json(error instanceof ApiError ? error.status : 503,
        { error: { code: error instanceof ApiError ? error.code : 'SERVICE_UNAVAILABLE',
          message: error instanceof ApiError ? error.message : 'Service unavailable. Retry later.', requestId } });
      else response.end();
    }
  });
  server.requestTimeout = 30_000;
  server.headersTimeout = 15_000;
  server.keepAliveTimeout = 5_000;
  return server;
}
