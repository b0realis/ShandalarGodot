/* Generated from the exact hosted files. Updates wait for every old window
 * to close; deliberately NO skipWaiting and NO reload of a running duel. */
'use strict';
const CONFIG = /*@@CONFIG@@*/;
const ROOT = self.registration.scope;
const PREFIX = 'shandalar-offline:' + encodeURIComponent(ROOT) + ':';
const CACHE = PREFIX + CONFIG.build;
const FILES = new Map(CONFIG.files.map(file => [new URL(file.url, ROOT).href, file]));
let repair;

function restore() {
  if (!repair) repair = save().finally(() => { repair = null; });
  return repair;
}

async function tell(message) {
  const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  for (const client of clients) if (client.url.startsWith(ROOT)) client.postMessage(message);
}
async function ready() {
  const cache = await caches.open(CACHE);
  const keys = new Set((await cache.keys()).map(key => key.url));
  return [...FILES.keys()].every(url => keys.has(url));
}
async function save() {
  const cache = await caches.open(CACHE);
  let done = 0;
  for (const [url, file] of FILES) {
    if (await cache.match(url)) { done += file.bytes; continue; }
    await tell({ type: 'PROGRESS', done, total: CONFIG.bytes, file: file.url });
    const controller = new AbortController();
    let timer = setTimeout(() => controller.abort(), 60000);
    try {
      const response = await fetch(url, { cache: 'no-store', redirect: 'error', signal: controller.signal });
      if (!response.ok) throw new Error(file.url + ' returned HTTP ' + response.status);
      // Stream to browser storage: large art ZIPs never become one JS buffer.
      // Validate the decompressed byte count even on compressed HTTPS hosts.
      let received = 0, last = 0;
      const hash = new Hash256();
      const counter = new TransformStream({
        async transform(chunk, output) {
          clearTimeout(timer); timer = setTimeout(() => controller.abort(), 60000);
          received += chunk.byteLength;
          hash.update(chunk);
          if (received > file.bytes) throw new Error(file.url + ' changed; ask the host to refresh the offline manifest');
          const now = Date.now();
          if (now - last > 250) { last = now; await tell({ type: 'PROGRESS', done: done + received, total: CONFIG.bytes, file: file.url }); }
          output.enqueue(chunk);
        },
        flush() {
          if (received !== file.bytes) throw new Error(file.url + ' was incomplete');
          if (hash.hex() !== file.sha256) throw new Error(file.url + ' changed; ask the host to refresh the offline manifest');
        },
      });
      const headers = new Headers(response.headers);
      headers.delete('content-encoding'); headers.delete('transfer-encoding');
      headers.set('content-length', String(file.bytes));
      await cache.put(url, new Response(response.body.pipeThrough(counter), { status: 200, headers }));
      done += file.bytes;
      await tell({ type: 'PROGRESS', done, total: CONFIG.bytes, file: file.url });
    } finally { clearTimeout(timer); }
  }
}
self.addEventListener('install', event => {
  event.waitUntil(save().catch(async error => {
    await caches.delete(CACHE); // Only this failed new version, never the working one.
    await tell({ type: 'FAILED', message: error.message });
    throw error;
  }));
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    if (!(await ready())) throw new Error('Offline installation is incomplete');
    // Natural activation happens only after the old version has no clients.
    for (const key of await caches.keys()) if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    await self.clients.claim();
  })());
});
self.addEventListener('message', event => {
  if (!event.source || !event.source.url.startsWith(ROOT)) return;
  if (event.data?.type === 'STATUS') {
    event.waitUntil(ready().then(value => event.ports[0]?.postMessage({ ready: value, version: CONFIG.version, bytes: CONFIG.bytes, build: CONFIG.build })));
  } else if (event.data?.type === 'REPAIR') {
    event.waitUntil(restore().then(() => tell({ type: 'REPAIRED' }))
      .catch(error => tell({ type: 'FAILED', message: error.message })));
  }
});
self.addEventListener('fetch', event => {
  if (!['GET', 'HEAD'].includes(event.request.method)) return;
  const url = new URL(event.request.url);
  const base = new URL(ROOT);
  if (url.origin !== base.origin || !url.pathname.startsWith(base.pathname)) return;
  url.search = ''; url.hash = '';
  if (url.href === ROOT) url.pathname += 'index.html';
  if (!FILES.has(url.href)) {
    // Absent optional art is a normal 404, including while completely offline.
    if (['skin/original_skin.zip', 'skin/cardart.zip'].some(name => url.href === new URL(name, ROOT).href)) {
      event.respondWith(fetch(event.request).catch(() => new Response('', { status: 404 })));
    }
    return;
  }
  event.respondWith((async () => {
    let cached = await (await caches.open(CACHE)).match(url.href);
    if (!cached) {
      // Restore exactly this version before returning any missing game file.
      // Partial eviction must never mix new network files with an old pack.
      try { await restore(); cached = await (await caches.open(CACHE)).match(url.href); } catch (_) { /* recovery below */ }
      if (!cached) {
        // The host may now hold only a newer build. Allow its background
        // registration script (not its game) to download the waiting update.
        if (url.href === new URL('offline.js', ROOT).href) {
          try { return await fetch(event.request); } catch (_) { /* reconnect */ }
        }
        const message = 'Offline files are incomplete. Reconnect and wait for the background download, then close ALL game windows and reopen. See OFFLINE-SETUP.txt. Your saved game data is separate.';
        if (url.href === new URL('index.html', ROOT).href) {
          return new Response('<!doctype html><meta charset="utf-8"><title>Shandalar — reconnect</title><p>' + message + '</p><script src="offline.js" defer></script>',
            { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
        }
        return new Response(message, { status: 503 });
      }
    }
    // Godot asks HEAD before fetching its skin. HEAD must work offline too.
    return event.request.method === 'HEAD'
      ? new Response(null, { status: cached.status, headers: cached.headers }) : cached;
  })());
});
