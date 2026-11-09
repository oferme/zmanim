// שומר עותק של המסך כדי שייפתח גם כשאין אינטרנט
// רק דפי המסך / האפליקציות וקבצים קטנים שלהם. הורדות (zip, סקריפטים) ומדריכים – בלי התערבות, ישר מהשרת.
const CACHE = 'zmanim-cache-2';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(CACHE).then(c => c.addAll(['./']))); });
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;   // רק קבצי האתר עצמו
  if (/\.(zip|ps1|bat|exe|ico|pdf|mp4)$/i.test(u.pathname) || /\/(pc|tv)\//.test(u.pathname)) return;   // הורדות ומדריכים – לא דרך המטמון
  e.respondWith(
    fetch(e.request).then(r => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); } return r; })
      .catch(() => caches.match(e.request, {ignoreSearch: true}).then(r => r || (e.request.mode === 'navigate' ? caches.match('./') : Response.error())))
  );
});
