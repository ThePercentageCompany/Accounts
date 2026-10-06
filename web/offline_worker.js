// Generated for release by scripts/prepare_offline_web.mjs. Development builds
// intentionally do not cache an incomplete shell.
const VERSION = '__TPC_SHELL_VERSION__';
const FILES = [];
const CACHE = 'tpc-shell-' + VERSION;
const resources = new Set(FILES.map(file => new URL(file, self.registration.scope).href));
self.addEventListener('install', event => {
  if (!FILES.length) return;
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES)));
  // No skipWaiting: a running app must not mix old Dart code with new assets.
});
self.addEventListener('activate', event => {
  if (!FILES.length) return;
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key.startsWith('tpc-shell-') && key !== CACHE)
    .map(key => caches.delete(key)))));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin ||
      url.pathname.startsWith('/v1/') || url.pathname === '/health' || !FILES.length) return;
  const navigation = event.request.mode === 'navigate';
  if (!navigation && !resources.has(url.href)) return;
  event.respondWith(caches.open(CACHE).then(async cache => {
    const target = navigation ? new URL('index.html', self.registration.scope).href : url.href;
    return await cache.match(target) || fetch(event.request);
  }));
});
