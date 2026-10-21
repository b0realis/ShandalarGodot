/* Browser regression gate. Needs Playwright, Python 3 and a browser.
 * --game-dir optionally adds a cold, offline boot of a real release.
 * --output saves screenshots/logs outside the source tree. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const arg = name => { const i = process.argv.indexOf(name); return i < 0 ? null : process.argv[i + 1]; };
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('node tools/test_web_offline.cjs [--browser chromium|webkit] [--channel chrome|chromium] [--game-dir EXTRACTED_OFFLINE_PACKAGE] [--output FOLDER]');
  process.exit(0);
}
if (process.argv.includes('--version')) {
  console.log(fs.readFileSync(path.join(root, 'project.godot'), 'utf8').match(/config\/version="([^"]+)"/)[1]);
  process.exit(0);
}
// Read after --help/--version, so those two answer on a machine without it.
const playwright = require('playwright');
const kind = arg('--browser') || 'chromium';
assert.ok(['chromium', 'webkit'].includes(kind));
// Which Chromium: the desk's installed Chrome ('chrome', the default), or
// the one Playwright pins and installs itself ('chromium'), as the CI job in
// .github/workflows/gate.yml does (review of 2026-10-21).
const channel = arg('--channel') || 'chrome';
assert.ok(['chrome', 'chromium'].includes(channel));
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'shandalar-web-offline-test-'));
const output = arg('--output') || scratch;
fs.mkdirSync(output, { recursive: true });
const originFiles = path.join(scratch, 'sites');
fs.mkdirSync(originFiles);
const gameDir = arg('--game-dir');
const faults = new Map();
let disconnected = false, requests = 0;
const mime = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
  '.webmanifest': 'application/manifest+json', '.png': 'image/png', '.zip': 'application/zip' };
const server = http.createServer((req, res) => {
  requests++;
  if (disconnected) { res.destroy(); return; }
  const parts = new URL(req.url, 'http://localhost').pathname.split('/').filter(Boolean);
  const site = parts.shift();
  const folder = site === 'game' ? gameDir : path.join(originFiles, site || '');
  const name = parts.join('/') || 'index.html';
  const file = folder && path.resolve(folder, name);
  if (!file || !file.startsWith(path.resolve(folder) + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    res.writeHead(404); res.end(); return;
  }
  const fault = faults.get(`${site}/${name}`);
  if (fault === 'missing') { res.writeHead(404); res.end(); return; }
  let data = fs.readFileSync(file);
  if (fault === 'corrupt') { data = Buffer.from(data); data[0] ^= 1; }
  res.writeHead(200, { 'Content-Type': mime[path.extname(name)] || 'application/octet-stream',
    'Content-Length': data.length, 'Cache-Control': 'no-store' });
  res.end(req.method === 'HEAD' ? undefined : data);
});
function refresh(folder) {
  const result = spawnSync(process.env.PYTHON || 'python3', ['-c',
    'import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); import package_web_offline; package_web_offline.prepare(Path(sys.argv[2]))',
    __dirname, folder], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
}
function fixture(site) {
  const folder = path.join(originFiles, site);
  fs.mkdirSync(path.join(folder, 'skin'), { recursive: true });
  for (const [name, value] of Object.entries({
    'VERSION.txt': '0.50.34', 'index.html': '<!doctype html><html><head><title>Fixture game</title></head><body><p id="game">game ready</p></body></html>',
    'index.js': 'original-js', 'index.wasm': 'original-wasm', 'index.pck': 'original-pck',
    'skin/original_skin.zip': 'fixture-skin',
  })) fs.writeFileSync(path.join(folder, name), value);
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=', 'base64');
  fs.writeFileSync(path.join(folder, 'index.icon.png'), png);
  fs.writeFileSync(path.join(folder, 'index.apple-touch-icon.png'), png);
  refresh(folder);
  return folder;
}
function hashes() {
  const code = fs.readFileSync(path.join(__dirname, 'web_offline/sha256.js'), 'utf8');
  const Hash256 = vm.runInNewContext(code + '\nHash256');
  for (const length of [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 1000000]) {
    const data = crypto.randomBytes(length), expected = crypto.createHash('sha256').update(data).digest('hex');
    for (const chunk of [1, 13, 64, 8191]) {
      if (length > 1000 && chunk === 1) continue;
      const hash = new Hash256();
      for (let i = 0; i < data.length; i += chunk) hash.update(data.subarray(i, i + chunk));
      assert.equal(hash.hex(), expected, `SHA-256 ${length}/${chunk}`);
    }
  }
  console.log('PASS streamed SHA-256 boundary/chunk vectors');
}
const launch = kind === 'chromium'
  ? { headless: true, channel, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] }
  : { headless: true };
async function install(page, url) {
  console.log('Installing ' + new URL(url).pathname);
  await page.goto(url);
  try {
    await page.waitForFunction(() => window.shandalarOffline?.state === 'ready', null, { timeout: 180000 });
  } catch (error) {
    console.error('INSTALL STATUS', await page.evaluate(() => window.shandalarOffline));
    throw error;
  }
  console.log('Installed ' + new URL(url).pathname);
}
async function regressions(browser, base) {
  const context = await browser.newContext();
  try {
    const alpha = fixture('alpha'); fixture('beta'); fixture('failed');
    const page = await context.newPage();
    await install(page, base + '/alpha/');
    await page.evaluate(async () => {
      const reg = await navigator.serviceWorker.getRegistration();
      navigator.serviceWorker.dispatchEvent(new MessageEvent('message', {
        source: reg.active, data: { type: 'PROGRESS', done: 1, total: 1, file: 'late event' },
      }));
    });
    assert.equal(await page.evaluate(() => window.shandalarOffline.state), 'ready');
    assert.equal(await page.locator('button').count(), 0);
    assert.equal(await page.locator('body').textContent(), 'game ready');
    console.log('PASS no extra UI; late installer progress cannot overwrite ready state');
    assert.equal(await page.evaluate(async () => (await fetch('skin/original_skin.zip', { method: 'HEAD' })).headers.get('content-length')), '12');
    // Disable the actual HTTP server; WebKit's automation offline switch
    // can reject a navigation before its service worker sees it.
    disconnected = true;
    if (kind === 'chromium') await context.setOffline(true);
    await page.close();
    const cold = await context.newPage();
    await cold.goto(base + '/alpha/?home=1');
    await cold.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    assert.equal(await cold.evaluate(async () => (await fetch('skin/original_skin.zip', { method: 'HEAD' })).status), 200);
    assert.equal(await cold.evaluate(async () => (await fetch('skin/cardart.zip')).status), 404);
    await cold.locator('#game').waitFor();
    console.log('PASS direct cold offline game, query URL, cached HEAD and absent art');
    disconnected = false;
    if (kind === 'chromium') await context.setOffline(false);
    const beta = await context.newPage();
    await install(beta, base + '/beta/');
    // Keep a game open during the update; old content must stay active.
    const oldCache = await cold.evaluate(async () => (await caches.keys()).find(name => name.includes('%2Falpha%2F')));
    fs.writeFileSync(path.join(alpha, 'index.js'), 'updated--js');
    refresh(alpha);
    const control = await context.newPage();
    await control.goto(base + '/alpha/');
    await control.waitForFunction(() => window.shandalarOffline?.state === 'waiting');
    assert.equal(await cold.evaluate(async () => (await fetch('index.js')).text()), 'original-js');
    await cold.close(); await control.close();
    const updated = await context.newPage();
    await updated.goto(base + '/alpha/');
    await updated.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    assert.equal(await updated.evaluate(async () => (await fetch('index.js')).text()), 'updated--js');
    assert.equal(await updated.evaluate(async key => (await caches.keys()).includes(key), oldCache), false);
    assert.equal(await beta.evaluate(async () => (await fetch('index.js')).text()), 'original-js');
    console.log('PASS update waits for the old game; cache cleanup preserves a sibling app');
    // Same-size corruption must fail SHA-256 and preserve the current version.
    fs.writeFileSync(path.join(alpha, 'index.pck'), 'changed--pck'); refresh(alpha);
    faults.set('alpha/index.pck', 'corrupt');
    await updated.reload();
    await updated.waitForFunction(() => window.shandalarOffline?.state === 'error');
    assert.equal(await updated.evaluate(async () => (await fetch('index.pck')).text()), 'original-pck');
    faults.delete('alpha/index.pck');
    console.log('PASS corrupt same-size update refused without replacing the working game');
    await beta.evaluate(async () => {
      const key = (await caches.keys()).find(name => name.includes('%2Fbeta%2F'));
      await (await caches.open(key)).delete(new URL('index.wasm', location.href).href);
    });
    await beta.reload();
    await beta.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    assert.equal(await beta.evaluate(async () => (await fetch('index.wasm')).text()), 'original-wasm');
    console.log('PASS partial eviction repaired automatically');
    await beta.evaluate(async () => {
      const key = (await caches.keys()).find(name => name.includes('%2Fbeta%2F'));
      await caches.delete(key);
    });
    await beta.reload();
    await beta.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    await beta.locator('#game').waitFor();
    console.log('PASS complete cache eviction recovers the original game online');
    // An evicted older version must not mix its runtime with a newer host.
    await beta.evaluate(async () => {
      localStorage.setItem('saved-deck-test', 'keep this');
      const key = (await caches.keys()).find(name => name.includes('%2Fbeta%2F'));
      await caches.delete(key);
    });
    const betaFolder = path.join(originFiles, 'beta');
    fs.writeFileSync(path.join(betaFolder, 'index.js'), 'newer-engine'); refresh(betaFolder);
    const recovery = await beta.reload();
    assert.equal(recovery.status(), 503);
    await beta.waitForFunction(() => window.shandalarOffline?.state === 'waiting');
    await beta.close();
    const recovered = await context.newPage();
    await recovered.goto(base + '/beta/');
    await recovered.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    assert.equal(await recovered.evaluate(async () => (await fetch('index.js')).text()), 'newer-engine');
    assert.equal(await recovered.evaluate(() => localStorage.getItem('saved-deck-test')), 'keep this');
    console.log('PASS eviction plus changed host recovers without mixed versions or clearing player storage');
    const failed = await context.newPage();
    faults.set('failed/index.wasm', 'missing');
    await failed.goto(base + '/failed/');
    await failed.waitForFunction(() => window.shandalarOffline?.state === 'error');
    await failed.locator('#game').waitFor();
    faults.delete('failed/index.wasm');
    await failed.reload();
    await failed.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    console.log('PASS incomplete first install can retry without false ready state');
  } finally { disconnected = false; await context.close(); }
}
async function realGame(base) {
  if (!gameDir) return;
  const profile = path.join(scratch, 'profile');
  let context = await playwright[kind].launchPersistentContext(profile, { ...launch, viewport: { width: 1280, height: 800 } });
  try {
    let page = await context.newPage();
    await install(page, base + '/game/');
    await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 180000 });
    await page.waitForTimeout(12000);
    await page.screenshot({ path: path.join(output, kind + '-offline-ready.png') });
    await context.close();
    // A new browser process, same profile, network blocked and server disabled.
    disconnected = true;
    const before = requests;
    context = await playwright[kind].launchPersistentContext(profile, { ...launch, offline: kind === 'chromium', viewport: { width: 1280, height: 800 } });
    page = await context.newPage();
    const logs = [], errors = [];
    page.on('console', msg => logs.push({ type: msg.type(), text: msg.text() }));
    page.on('pageerror', error => errors.push(String(error)));
    await page.goto(base + '/game/', { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.shandalarOffline?.state === 'ready');
    await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 180000 });
    await page.waitForTimeout(12000);
    await page.screenshot({ path: path.join(output, kind + '-offline-title.png') });
    await page.locator('canvas').focus();
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(output, kind + '-offline-setup.png') });
    await page.mouse.click(798, 97);
    await page.waitForTimeout(500);
    await page.mouse.click(740, 751);
    await page.waitForTimeout(18000);
    await page.screenshot({ path: path.join(output, kind + '-offline-duel.png') });
    const fatal = logs.filter(item => /^(SCRIPT ERROR:|ERROR:)|RuntimeError|Aborted\(/.test(item.text));
    fs.writeFileSync(path.join(output, kind + '-game-console.json'), JSON.stringify({ logs, errors, fatal, requestsAfterDisconnect: requests - before }, null, 2));
    assert.deepEqual(errors, []); assert.deepEqual(fatal, []);
    // Some browser internals may probe the dead server; no response is delivered.
    console.log('PASS real game cold process restart offline; title/duel screenshots need visual review');
  } finally { await context.close(); disconnected = false; }
}
(async () => {
  let browser;
  try {
    hashes();
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    browser = await playwright[kind].launch(launch);
    await regressions(browser, base);
    await browser.close(); browser = null;
    await realGame(base);
    console.log('ALL OFFLINE WEB CHECKS PASSED (' + kind + ')');
  } finally {
    if (browser) await browser.close();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    if (output !== scratch) fs.rmSync(scratch, { recursive: true, force: true });
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
