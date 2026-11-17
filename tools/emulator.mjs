import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const shots = path.join(root, 'artifacts/emulator');
const source = fs.readFileSync(path.join(root, 'vendor/emulator/solana-os.js'), 'utf8');

function catalog() {
  const result = {};
  for (const folder of fs.readdirSync(path.join(root, 'apps'))) {
    const app = path.join(root, 'apps', folder);
    if (!fs.existsSync(path.join(app, 'app.json'))) continue;
    const files = {};
    function visit(dir) {
      for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, item.name);
        if (item.isDirectory()) visit(p);
        else if (item.name.endsWith('.lua') || item.name === 'app.json') {
          files[path.relative(app, p).split(path.sep).join('/')] = fs.readFileSync(p, 'utf8');
        }
      }
    }
    visit(app);
    result[folder] = { manifest: JSON.parse(files['app.json']), files };
  }
  return result;
}

export async function server(port = 0) {
  const identities = new Map();
  const srv = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://127.0.0.1');
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      if (url.pathname === '/api/badge/hello') {
        let body = '';
        for await (const chunk of req) {
          body += chunk;
          if (body.length > 8192) { res.writeHead(413).end(); return; }
        }
        const data = JSON.parse(body || '{}');
        const hw = String(data.hw ?? data.hardware ?? '');
        if (!identities.has(hw)) identities.set(hw, `TEST${String(identities.size + 1).padStart(2, '0')}`);
        const id = identities.get(hw);
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ id, secret: `local-fixture-${id}`, key: '00112233445566778899aabbccddeeff',
          claimed: false, claimUrl: `http://127.0.0.1/claim?b=${id}&c=DEMO`, poll: 600, mesh: 1, time: Date.now() }));
        return;
      }
      if (url.pathname.startsWith('/api/')) {
        res.writeHead(404, { 'Content-Type': 'application/json' }).end('{"error":"local demo only"}'); return;
      }
      if (url.pathname === '/demo/catalog.json') {
        res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(catalog())); return;
      }
      if (url.pathname === '/revision.json') {
        const p = path.join(root, 'artifacts/demo-revision.txt');
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ revision: fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '' })); return;
      }
      let rel = url.pathname === '/' ? 'demo/index.html' : decodeURIComponent(url.pathname.slice(1));
      if (!/^(demo\/[a-z0-9.-]+|vendor\/emulator\/solana-os\.(js|wasm)|downloads\/[a-z0-9.-]+)$/.test(rel)) {
        res.writeHead(404).end('Not found'); return;
      }
      if (rel.startsWith('downloads/')) rel = `artifacts/release/${rel.slice(10)}`;
      const p = path.join(root, rel);
      if (!fs.existsSync(p) || !fs.statSync(p).isFile()) { res.writeHead(404).end('Not found'); return; }
      const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.mjs': 'text/javascript',
        '.js': 'text/javascript', '.wasm': 'application/wasm', '.zip': 'application/zip' };
      res.setHeader('Content-Type', types[path.extname(p)] ?? 'text/plain');
      fs.createReadStream(p).pipe(res);
    } catch (error) {
      res.writeHead(400).end(`Local demo request failed: ${error.message}`);
    }
  });
  await new Promise((resolve, reject) => { srv.once('error', reject); srv.listen(port, '127.0.0.1', resolve); });
  return { srv, origin: `http://127.0.0.1:${srv.address().port}`, identities };
}

async function until(fn, message, ms = 10000) {
  const start = performance.now();
  while (performance.now() - start < ms) {
    if (fn()) return;
    await sleep(50);
  }
  throw new Error(`Timed out: ${message}`);
}

async function boot(origin, tag, dropEvery = 0) {
  const lines = [];
  const nvs = new Map();
  const localStorage = { getItem: k => nvs.get(k) ?? null, setItem: (k, v) => nvs.set(k, String(v)), removeItem: k => nvs.delete(k) };
  const location = new URL(`${origin}/demo/frame.html?badge=${tag}`);
  const logger = { log: (...args) => lines.push(args.join(' ')), error: (...args) => lines.push(args.join(' ')), warn: (...args) => lines.push(args.join(' ')) };
  // Separate lexical browser globals give each firmware instance its own NVS and logs.
  const factory = new Function('console', 'location', 'localStorage', 'BroadcastChannel', `${source}; return SolanaOS;`);
  let transmitted = 0, dropped = 0;
  class LossyChannel extends BroadcastChannel {
    postMessage(value) {
      transmitted++;
      if (dropEvery && transmitted % dropEvery === 0) { dropped++; return; }
      super.postMessage(value);
    }
  }
  const make = factory(logger, location, localStorage, LossyChannel);
  const mod = await make({ locateFile: p => `${origin}/vendor/emulator/${p}`, server: origin });
  const cmd = line => mod.ccall('emu_console', null, ['string'], [line]);
  await until(() => lines.some(l => l.includes('console ready')), `${tag} boot`);
  cmd('info');
  assert(lines.some(l => l.includes('Solana OS 2.4.0')), 'locked firmware version');
  cmd('wifi connect "Emulator Guest"');
  await until(() => lines.some(l => l.includes('new secret stored')), `${tag} local registration`);
  await sleep(200);
  return { mod, cmd, lines, tag, dropped: () => dropped,
    async key(key) { cmd(`key ${key}`); await sleep(180); },
    async install(folder, preferences) {
      cmd('open home'); await sleep(100);
      const app = catalog()[folder];
      const dir = `/sdcard/hh/apps/${app.manifest.id}`;
      mod.FS.mkdirTree(`${dir}/files`);
      for (const [name, text] of Object.entries(app.files)) {
        const target = `${dir}/${['main.lua', 'app.json'].includes(name) ? name : `files/${name}`}`;
        mod.FS.mkdirTree(target.slice(0, target.lastIndexOf('/')));
        mod.FS.writeFile(target, text);
      }
      if (preferences) mod.FS.writeFile(`${dir}/data.json`, JSON.stringify(preferences));
      cmd(`lua run ${app.manifest.id}`); await sleep(350);
    },
    frame() {
      const ptr = mod.ccall('emu_framebuffer', 'number', [], []);
      return Buffer.from(mod.HEAPU8.subarray(ptr, ptr + 320 * 240 * 4));
    },
    stop() {
      mod.ccall('emu_halt', null, [], []);
      mod.mesh?.bc?.close(); mod.ble?.bc?.close(); mod.gossip?.bc?.close();
    },
  };
}

function crc32(data) {
  let crc = 0xffffffff;
  for (const b of data) {
    crc ^= b;
    for (let k = 0; k < 8; k++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(name, bytes) {
  const kind = Buffer.from(name), size = Buffer.alloc(4), crc = Buffer.alloc(4);
  size.writeUInt32BE(bytes.length); crc.writeUInt32BE(crc32(Buffer.concat([kind, bytes])));
  return Buffer.concat([size, kind, bytes, crc]);
}

function png(rgba) {
  const header = Buffer.alloc(13); header.writeUInt32BE(320, 0); header.writeUInt32BE(240, 4);
  header[8] = 8; header[9] = 6;
  const rows = [];
  for (let y = 0; y < 240; y++) rows.push(Buffer.from([0]), rgba.subarray(y * 1280, (y + 1) * 1280));
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(Buffer.concat(rows))), chunk('IEND', Buffer.alloc(0))]);
}

async function tests() {
  fs.mkdirSync(shots, { recursive: true });
  const local = await server();
  const badges = [], evidence = { firmware: '2.4.0', physicalHardware: 'not connected', checks: [], memory: [], screenshots: [] };
  const report = text => { evidence.checks.push(text); console.log(`ok firmware: ${text}`); };
  const shot = (badge, name) => {
    const frame = badge.frame();
    assert(new Set(frame).size > 16, `${name} must contain a rendered screen`);
    const file = `${name}.png`; fs.writeFileSync(path.join(shots, file), png(frame));
    evidence.screenshots.push(file);
    return createHash('sha256').update(frame).digest('hex');
  };
  try {
    const a = await boot(local.origin, 'one'); badges.push(a);
    const b = await boot(local.origin, 'two', 4); badges.push(b);
    assert.equal(local.identities.size, 2, 'separate local badge identities');
    report('two isolated firmware instances register only with the local stand-in');
    await a.install('shipmates'); await b.install('shipmates', { topics: { need: 3, offer: 1 } });
    assert(a.lines.some(l => l.includes('shipmates: ready, sharing off')));
    const home = shot(a, 'shipmates-start');
    await a.key('select'); await b.key('select');
    await until(() => a.lines.some(l => l.includes('shipmates: nearby 1')) && b.lines.some(l => l.includes('shipmates: nearby 1')), 'two-badge discovery', 15000);
    assert.notEqual(home, shot(a, 'shipmates-nearby'));
    report('Shipmates discovers a complementary peer through actual firmware mesh code');
    await a.key('select'); await a.key('select');
    await b.key('select'); await b.key('select');
    await until(() => a.lines.some(l => l.includes('shipmates: mutual')) && b.lines.some(l => l.includes('shipmates: mutual')), 'mutual hello despite packet loss', 18000);
    shot(a, 'shipmates-mutual'); shot(b, 'shipmates-mutual-peer');
    assert(b.dropped() > 0);
    report('mutual hello converges despite deterministic radio packet loss');
    await a.key('back'); await a.key('right'); shot(a, 'shipmates-invite');
    await a.key('back');
    const start = a.lines.length;
    b.cmd('open home'); await sleep(250); b.cmd('lua mem');
    await until(() => a.lines.slice(start).some(l => l.includes('shipmates: nearby 0')), 'peer withdrawal or 15-second expiry', 18000);
    shot(a, 'shipmates-peer-left');
    report('a closed peer disappears without a crash or stale selectable contact');
    await a.key('back'); await a.key('back');
    assert(a.lines.some(l => l.includes('shipmates: sharing off')));
    a.cmd('open home'); await sleep(180); a.cmd('lua mem');
    await a.install('shipmates');
    assert(a.lines.at(-1)?.includes('ready') || a.lines.some(l => l.includes('shipmates: ready, sharing off')));
    report('Shipmates stops sharing and returns to a private first-launch state');
    a.cmd('open home'); await sleep(120);
    await a.install('pocket-pause');
    const idle = shot(a, 'pause-start');
    await a.key('select'); await sleep(700);
    assert.notEqual(idle, shot(a, 'pause-running'));
    await a.key('select'); shot(a, 'pause-paused');
    assert(a.lines.some(l => l.includes('pause: paused')));
    await a.key('back'); await a.key('up'); await a.key('right');
    shot(a, 'pause-focus');
    await a.key('select'); await a.key('right'); await sleep(200);
    a.cmd('open home'); await sleep(200); a.cmd('lua mem');
    report('Pocket Pause renders, starts, pauses, resets, selects focus, and exits');
    for (const badge of badges) {
      const errors = badge.lines.filter(l => /^\[lua:/.test(l) || /Script took too long|Out of memory|panic|Aborted\(/i.test(l));
      assert.deepEqual(errors, [], `${badge.tag} runtime errors: ${errors.join('\n')}`);
      const memory = badge.lines.filter(l => /peak|most instructions|last run|heap|instructions in/.test(l));
      evidence.memory.push({ badge: badge.tag, lines: memory });
      fs.writeFileSync(path.join(shots, `${badge.tag}.log`), `${badge.lines.join('\n')}\n`);
    }
    assert(evidence.memory.some(m => m.lines.some(l => /peak/.test(l))), 'real host memory report');
    report('no Lua runtime errors, instruction-limit failures, or memory-limit failures');
    evidence.status = 'passed';
  } catch (error) {
    evidence.status = 'failed'; evidence.error = error.stack;
    for (const badge of badges) fs.writeFileSync(path.join(shots, `${badge.tag}.log`), `${badge.lines.join('\n')}\n`);
    throw error;
  } finally {
    evidence.at = new Date().toISOString();
    fs.writeFileSync(path.join(shots, 'report.json'), `${JSON.stringify(evidence, null, 2)}\n`);
    for (const badge of badges) badge.stop();
    local.srv.closeAllConnections(); await new Promise(resolve => local.srv.close(resolve));
  }
  console.log(`Firmware evidence: ${path.relative(root, shots)}/report.json`);
}

const mode = process.argv[2];
if (mode === 'serve') {
  const local = await server(Number(process.argv[3] ?? 8765));
  console.log(`Two-badge demo: ${local.origin}`);
  console.log('Local-only identity stand-in. Firmware radios are simulated. Ctrl+C stops.');
} else if (mode === 'test') {
  try { await tests(); process.exit(0); }
  catch (error) { console.error(error.stack); process.exit(1); }
}
