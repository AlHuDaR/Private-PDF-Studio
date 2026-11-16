"""Create a versioned, same-origin, static-only offline cache after web builds."""
import hashlib
import json
from pathlib import Path

root = Path('build/web')
if not (root / 'main.dart.js').is_file():
    raise SystemExit('Build Flutter web before generating the offline cache')
files = sorted(p for p in root.rglob('*') if p.is_file()
               and p.name not in {'offline_worker.js', 'flutter_service_worker.js'}
               and p.suffix != '.map')
digest = hashlib.sha256()
for path in files:
    digest.update(path.relative_to(root).as_posix().encode())
    digest.update(path.read_bytes())
urls = ['./'] + ['./' + p.relative_to(root).as_posix() for p in files]
worker = ''''use strict';
const CACHE = 'pdf-studio-__VERSION__';
const ASSETS = __ASSETS__;
const ALLOWED = new Set(ASSETS.map(p => new URL(p, self.registration.scope).href));
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(k => k.startsWith('pdf-studio-') && k !== CACHE)
      .map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  // Only build-time static assets are cached. Never handle document blobs,
  // dynamic URLs, query strings, cross-origin requests, POSTs or user files.
  if (request.method !== 'GET' || !ALLOWED.has(request.url)) return;
  event.respondWith(caches.open(CACHE).then(async cache => {
    const response = await cache.match(request);
    return response || fetch(request);
  }));
});
'''
(root / 'offline_worker.js').write_text(
    worker.replace('__VERSION__', digest.hexdigest()[:20])
          .replace('__ASSETS__', json.dumps(urls)), encoding='utf-8')
print(f'Offline cache generated for {len(urls)} static resources')
