/* Replaced by tool/build_pwa.mjs with a content-addressed app-shell manifest. */
const VERSION = 'development';
const RESOURCES = ['index.html', 'manifest.json', 'pwa.js', 'flutter_bootstrap.js'];
const CACHE = `tpc-shell-${VERSION}`;
const scope = new URL(self.registration.scope);
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  await cache.addAll(RESOURCES.map(path => new Request(new URL(path, scope), {cache:'reload'})));
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const name of await caches.keys()) {
    if (name.startsWith('tpc-shell-') && name !== CACHE) await caches.delete(name);
  }
  await self.clients.claim();
})()));
self.addEventListener('message', event => {
  if (event.data?.type === 'ACTIVATE_UPDATE') self.skipWaiting();
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  // Auth, APIs, uploads and external resources never enter the shell cache.
  if (event.request.method !== 'GET' || url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;
  const path = url.pathname.slice(scope.pathname.length);
  if (path.startsWith('v1/') || path.startsWith('internal/')) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(caches.open(CACHE).then(cache => cache.match(new URL('index.html', scope))).then(result => result || fetch(event.request)));
  } else if (RESOURCES.includes(path)) {
    event.respondWith(caches.open(CACHE).then(cache => cache.match(new URL(path, scope))).then(result => result || fetch(event.request)));
  }
});
self.addEventListener('push', event => event.waitUntil((async () => {
  let data; try {data = event.data.json();} catch (_) {data = {};}
  await self.registration.showNotification(data.title || 'TPC Accounts', {
    body: data.body || 'You have a workspace update.',
    icon: new URL('icons/Icon-192.png', scope).href,
    badge: new URL('icons/Icon-192.png', scope).href,
    tag: data.id, data: {companyId: data.companyId, taskId: data.taskId},
  });
})()));
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const {companyId, taskId} = event.notification.data || {};
    if (!/^[A-Za-z0-9_-]{43}$/.test(companyId) || !/^[A-Za-z0-9_-]{43}$/.test(taskId)) return;
    for (const client of await self.clients.matchAll({type:'window', includeUncontrolled:true})) {
      if (new URL(client.url).origin === scope.origin && new URL(client.url).pathname.startsWith(scope.pathname)) {
        client.postMessage({type:'OPEN_TASK', companyId, taskId}); await client.focus(); return;
      }
    }
    await self.clients.openWindow(new URL(`#task=${companyId}:${taskId}`, scope).href);
  })());
});

// Best-effort closed-app delivery for safe local edits on supporting browsers.
// The Dart outbox performs full reconciliation on next launch. Financial online
// actions, dependencies, foreign API origins and browsers without Web Locks wait
// for foreground sync instead of risking an unsafe background write.
self.addEventListener('sync', event => {
  if (event.tag === 'tpc-outbox') event.waitUntil(backgroundSync());
});
async function backgroundSync() {
  if (!self.navigator.locks) return;
  const db = await new Promise((resolve, reject) => {
    const request = indexedDB.open('tpc_offline_v1');
    request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
  });
  if (!db.objectStoreNames.contains('partitions')) {db.close(); return;}
  const read = () => new Promise((resolve, reject) => {
    const tx = db.transaction('partitions'); const request = tx.objectStore('partitions').openCursor();
    const result = [];
    request.onsuccess = () => {const cursor = request.result; if (cursor) {result.push([cursor.key, cursor.value]); cursor.continue();}};
    tx.oncomplete = () => resolve(result); tx.onerror = () => reject(tx.error);
  });
  try {
    for (const [key] of await read()) {
      let parts; try {parts = JSON.parse(key);} catch (_) {continue;}
      if (!Array.isArray(parts) || parts.length !== 4 || new URL(parts[0]).origin !== scope.origin ||
          !['owner','employee'].includes(parts[1]) || !/^[A-Za-z0-9_-]{43}$/.test(parts[3])) continue;
      await self.navigator.locks.request(`tpc-outbox:${key}`, {ifAvailable:true}, async lock => {
        if (!lock) return;
        const partition = (await read()).find(([name]) => name === key)?.[1];
        const op = partition?.operations?.[0];
        if (!op || !op.local || op.state === 'failed' || op.dependsOn || op.backgroundAck ||
            op.retryAt > Date.now() || !['Customers','ProductsServices','Tasks','TaskComments','Invoices','Quotations'].includes(op.table)) return;
        if (!['create','update','delete'].includes(op.action) ||
            (op.table === 'TaskComments' && op.action !== 'create')) return;
        const employee = parts[1] === 'employee';
        const headers = {'Content-Type':'application/json', 'X-TPC-CSRF':'1'};
        const identity = await fetch(new URL(employee ? 'v1/employee/me' : 'v1/me', scope), {credentials:'include', cache:'no-store'});
        if (!identity.ok) return;
        const principal = (await identity.json())[employee ? 'employee' : 'owner'];
        if (principal?.[employee ? 'employeeId' : 'ownerId'] !== parts[2] ||
            (employee && principal.companyId !== parts[3])) return;
        const payload = Object.fromEntries(['operationId','table','action','recordId','expectedVersion','values']
          .filter(name => Object.hasOwn(op, name)).map(name => [name, op[name]]));
        const input = {operations:[payload], ...(employee ? {companyId:parts[3],employeeId:parts[2]} : {})};
        const response = await fetch(new URL(employee ? 'v1/employee/sync' : `v1/companies/${parts[3]}/sync`, scope),
          {method:'POST', headers, credentials:'include', cache:'no-store', body:JSON.stringify(input)});
        if (!response.ok) return;
        const result = (await response.json()).results?.[0];
        if (result?.operationId !== op.operationId || result.status !== 'APPLIED' ||
            typeof result.recordId !== 'string' || !Number.isSafeInteger(result.version)) return;
        await new Promise((resolve, reject) => {
          const tx = db.transaction('partitions','readwrite'); const store = tx.objectStore('partitions');
          const request = store.get(key);
          request.onsuccess = () => {
            const value = request.result; const first = value?.operations?.[0];
            if (first?.operationId === op.operationId) {first.backgroundAck = result; store.put(value,key);}
          };
          tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
        });
        try {const channel = new BroadcastChannel('tpc-cache-control-v2');
          channel.postMessage(JSON.stringify({kind:'outbox',scope:key})); channel.close();} catch (_) {}
      });
    }
  } finally {db.close();}
}
