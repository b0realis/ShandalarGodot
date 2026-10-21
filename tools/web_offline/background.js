/* Background offline support only. No added DOM, menus, prompts or reloads. */
'use strict';
(() => {
  let registration, repairing = false;
  // Diagnostic state for automated checks and a host's browser console.
  // Not a game setting; it is never written into the player's saved data.
  const status = window.shandalarOffline = { state: 'starting' };
  const scope = new URL('./', location.href).href;
  function state(value, detail = {}) {
    Object.assign(status, detail, { state: value });
    if (value === 'ready') console.info('Shandalar: offline copy complete. Close and reopen without a connection to verify.');
    if (value === 'waiting') console.info('Shandalar: update downloaded. Close all game windows to apply it next time.');
    if (value === 'error' || value === 'unsupported') console.warn('Shandalar offline: ' + status.message);
  }
  function request(worker) {
    return new Promise((resolve, reject) => {
      const channel = new MessageChannel();
      const timer = setTimeout(() => { channel.port1.close(); reject(new Error('offline worker did not answer')); }, 15000);
      channel.port1.onmessage = event => { clearTimeout(timer); channel.port1.close(); resolve(event.data); };
      worker.postMessage({ type: 'STATUS' }, [channel.port2]);
    });
  }
  async function inspect() {
    if (!registration?.active) return;
    const result = await request(registration.active);
    if (registration.waiting) { state('waiting', result); return; }
    if (result.ready) { state('ready', result); return; }
    if (!repairing) {
      repairing = true;
      state('saving', result);
      registration.active.postMessage({ type: 'REPAIR' });
    }
  }
  function observe(worker) {
    if (!worker) return;
    worker.addEventListener('statechange', () => {
      if (worker.state === 'activated' || (worker.state === 'installed' && registration.active)) {
        inspect().catch(error => state('error', { message: error.message }));
      }
      if (worker.state === 'redundant' && status.state === 'saving') {
        state('error', { message: 'download incomplete; reconnect and reopen to retry. Previous complete versions are kept.' });
      }
    });
  }
  async function start() {
    if (!isSecureContext || !('serviceWorker' in navigator) || !('caches' in window)) {
      state('unsupported', { message: 'HTTPS and service-worker storage are required; ordinary online play is unchanged.' });
      return;
    }
    const existing = await navigator.serviceWorker.getRegistration('./');
    if (existing && existing.scope !== scope) {
      state('unsupported', { message: 'another app controls this folder; use a dedicated hosting folder.' });
      return;
    }
    navigator.serviceWorker.addEventListener('message', event => {
      const data = event.data || {};
      if (data.type === 'PROGRESS') {
        if (event.source?.state !== 'installing' && !repairing) return;
        state('saving', { done: data.done, bytes: data.total });
      } else if (data.type === 'FAILED') {
        repairing = false;
        state('error', { message: data.message + '; reconnect and reopen to retry. See OFFLINE-SETUP.txt.' });
      } else if (data.type === 'REPAIRED') {
        repairing = false;
        inspect().catch(error => state('error', { message: error.message }));
      }
    });
    // On a disconnected return the existing worker still serves the game.
    // A network failure while checking for updates must not hide its status.
    registration = existing;
    try {
      registration = await navigator.serviceWorker.register('offline-sw.js', { scope: './', updateViaCache: 'none' });
    } catch (error) {
      if (!registration?.active) throw error;
    }
    observe(registration.installing);
    registration.addEventListener('updatefound', () => observe(registration.installing));
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      inspect().catch(error => state('error', { message: error.message }));
    });
    await inspect();
    // The host, not GitHub, supplies updates. Browser-managed activation
    // waits for all old clients; never use skipWaiting or reload the game.
    registration.update().catch(() => {});
  }
  start().catch(error => state('error', { message: error.message }));
})();
