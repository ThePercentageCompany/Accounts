/* Imported by tpc-sw.js, never registered at a competing root scope. */
async function showTaskPush(payload) {
  const data = payload.data || payload;
  if (!/^[A-Za-z0-9_-]{43}$/.test(data.companyId) || (data.taskId && !/^[A-Za-z0-9_-]{43}$/.test(data.taskId)) ||
      !/^[A-Za-z0-9_-]{43}$/.test(data.id)) return;
  const cache = await caches.open('tpc-push-dedup-v1').catch(() => null);
  const marker = new Request(new URL(`__push_seen/${data.id}`, self.registration.scope));
  if (await cache?.match(marker).catch(() => null)) return;
  await self.registration.showNotification(data.title || 'Workspace notification', {
    body: data.body || 'Open your workspace for details.',
    icon: new URL('icons/Icon-192.png', self.registration.scope).href,
    badge: new URL('icons/Icon-192.png', self.registration.scope).href,
    tag: data.id, silent: data.sound === 'none',
    data: {companyId: data.companyId, taskId: data.taskId, notificationId: data.id},
  });
  for (const client of await self.clients.matchAll({type: 'window', includeUncontrolled: true})) {
    if (new URL(client.url).origin === new URL(self.registration.scope).origin)
      client.postMessage({type: 'NOTIFICATION_RECEIVED', companyId: data.companyId});
  }
  if (cache) {
    await cache.put(marker, new Response('received')).catch(() => {});
    const keys = await cache.keys().catch(() => []);
    for (const key of keys.slice(0, Math.max(0, keys.length - 2000))) await cache.delete(key).catch(() => {});
  }
}

// FCM's background callback is skipped when it finds a visible page, even if
// that page cannot show a system alert. Handle the data-only push in the worker.
self.addEventListener('push', event => {
  if (!event.data) return;
  let payload;
  try {payload = event.data.json();} catch (_) {return;}
  if (payload?.data) event.waitUntil(showTaskPush(payload));
});

try {
  importScripts('firebase-config.js',
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');
  firebase.initializeApp(self.tpcFirebaseConfig);
  firebase.messaging(); // Preserve Firebase's subscription-change handling.
} catch (_) {
  // Display remains available if the optional SDK cannot load.
}
