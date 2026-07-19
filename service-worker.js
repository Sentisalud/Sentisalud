/* SentiSalud · Service Worker
   Estrategia:
   - App shell (HTML, manifest, íconos): cache-first, para que abra sin conexión.
   - farmacias.json: network-first (datos frescos si hay red, cache si no).
   - Cualquier origen externo (mapas CARTO, Leaflet CDN, datos.gov.co, Supabase):
     NO se intercepta ni se cachea — va directo a la red.
   Sube el número de versión para forzar actualización del shell. */
var VERSION = 'sentisalud-v7';
var SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './farmacias.json',
  './icons/favicon-32.png',
  './icons/apple-touch-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(VERSION).then(function (c) { return c.addAll(SHELL); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) {
        if (k !== VERSION) return caches.delete(k);
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;                 // no tocar POST (reportes/avisos)
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;  // recursos externos: directo a la red

  // farmacias.json -> network-first
  if (url.pathname.endsWith('/farmacias.json')) {
    e.respondWith(
      fetch(req).then(function (res) {
        var copy = res.clone();
        caches.open(VERSION).then(function (c) { c.put(req, copy); });
        return res;
      }).catch(function () { return caches.match(req); })
    );
    return;
  }

  // resto del shell -> cache-first con respaldo de red
  e.respondWith(
    caches.match(req).then(function (cached) {
      return cached || fetch(req).then(function (res) {
        var copy = res.clone();
        caches.open(VERSION).then(function (c) { c.put(req, copy); });
        return res;
      }).catch(function () {
        if (req.mode === 'navigate') return caches.match('./index.html');
      });
    })
  );
});
