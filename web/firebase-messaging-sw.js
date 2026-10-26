/* Imported by tpc-sw.js, never registered at a competing root scope. */
async function showTaskPush(payload) {
  const data = payload.data || payload;
  if (!/^[A-Za-z0-9_-]{43}$/.test(data.companyId) || !/^[A-Za-z0-9_-]{43}$/.test(data.taskId) ||
      !/^[A-Za-z0-9_-]{43}$/.test(data.id)) return;
  const cache = await caches.open('tpc-push-dedup-v1');
  const marker = new Request(new URL(`__push_seen/${data.id}`, self.registration.scope));
  if (await cache.match(marker)) return;
  await self.registration.showNotification(data.title || 'TPC task notification', {
    body: data.body || 'Open your workspace to view this task update.',
    icon: new URL('icons/Icon-192.png', self.registration.scope).href,
    badge: new URL('icons/Icon-192.png', self.registration.scope).href,
    tag: data.id, silent: data.sound === 'none',
    data: {companyId: data.companyId, taskId: data.taskId, notificationId: data.id},
  });
  await cache.put(marker, new Response('received'));
  const keys = await cache.keys(); for (const key of keys.slice(0, Math.max(0, keys.length - 2000))) await cache.delete(key);
  for (const client of await self.clients.matchAll({type: 'window', includeUncontrolled: true})) {
    if (new URL(client.url).origin === new URL(self.registration.scope).origin)
      client.postMessage({type: 'NOTIFICATION_RECEIVED', companyId: data.companyId});
  }
}
try {
  importScripts('firebase-config.js',
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');
  firebase.initializeApp(self.tpcFirebaseConfig);
  firebase.messaging().onBackgroundMessage(showTaskPush);
} catch (_) {
  // A network failure loading the optional SDK must not break PWA caching.
  self.addEventListener('push', event => event.waitUntil((async () => {
    try {await showTaskPush(event.data.json());} catch (_) {}
  })()));
}
