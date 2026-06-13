// Service worker para PWA
const CACHE = 'sumipanel-v1';
const ASSETS = ['/', '/index.html', '/favicon.svg', '/manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k!==CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if(e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request).then(resp => {
      const respClone = resp.clone();
      caches.open(CACHE).then(c => c.put(e.request, respClone));
      return resp;
    }).catch(() => caches.match('/index.html')))
  );
});
