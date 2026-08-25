const CACHE = 'ev-tracker-v3';
const ASSETS = ['./manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const req = e.request;

  // The Cache API only stores GET. The old worker tried to cache every response,
  // so each Gemini/Supabase POST threw an unhandled rejection in the console —
  // exactly the noise you don't want while debugging an API problem.
  // Non-GET requests are now left alone entirely and go straight to the network.
  if (req.method !== 'GET') return;

  // Network-first for everything: always get the latest, fall back to cache only if offline.
  // (index.html and app JS are deliberately NOT precached, so future edits show up immediately.)
  e.respondWith(
    fetch(req)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE)
          .then(c => c.put(req, copy))
          .catch(() => {});   // opaque/partial responses can't be stored — not an error worth surfacing
        return res;
      })
      .catch(() => caches.match(req))
  );
});
