// webOS 5 support: each Node step used where python3 is missing gives the same result as its Python step, and the
// timeout probe picks the syntax the TV's timeout accepts. Needs python3 and sh. Run: node tests/node-fallbacks.cjs
const fs = require('fs'), os = require('os'), path = require('path'), assert = require('assert');
const { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'atl-webos5-'));
const run = (cmd, args, input) => execFileSync(cmd, args, { encoding: 'utf8', input });

// The inline programs of a script: Python heredocs (<<'PY' ... PY) and node -e '...' blocks, in order.
const heredocs = (s) => [...s.matchAll(/<<'PY'\n([\s\S]*?)\nPY\n/g)].map((m) => m[1]);
const nodeBlocks = (s) => [...s.matchAll(/node -e '([\s\S]*?)'/g)].map((m) => m[1]);
const py = (code, args, input) => run('python3', ['-c', code, ...args], input);
const node = (code, args, input) => run(process.execPath, ['-e', code, ...args], input);
const write = (name, value) => { const p = path.join(tmp, name); fs.writeFileSync(p, typeof value === 'string' ? value : JSON.stringify(value)); return p; };

// ---- atlauncher.sh: the Home overlay's appinfo.json, and the key filter on / off ----
const atl = read('app/tools/atlauncher.sh');
const [buildPy, keysPy] = heredocs(atl);
const [buildJs, keysJs, keysOffJs] = nodeBlocks(atl);
const appinfo = write('appinfo.json', { id: 'com.ratelimits.atlauncher', version: '1.0.4', type: 'qml', main: 'main.qml', title: 'ATLauncher', icon: 'icon.png' });
for (const home of ['com.webos.app.home', 'com.webos.app.fullhome']) {
  const a = path.join(tmp, 'a.json'), b = path.join(tmp, 'b.json');
  py(buildPy, [appinfo, a, home]); node(buildJs, [appinfo, b, home]);
  assert.deepStrictEqual(JSON.parse(fs.readFileSync(b, 'utf8')), JSON.parse(fs.readFileSync(a, 'utf8')));
  assert.strictEqual(JSON.parse(fs.readFileSync(b, 'utf8')).id, home);
}
const CFG = 'com.webos.surfacemanager.keyFilters', MINE = '/var/lib/atlauncher/homekey.js';
const lists = {
  lg: [{ handler: 'a', file: '/x.js' }, { handler: 'b', file: '/x.js' }, { handler: 'handleScreenSaver', file: '/y.js' }, { handler: 'home', file: '/z.js' }],
  noScreenSaver: [{ handler: 'a', file: '/x.js' }, { handler: 'b', file: '/x.js' }, { handler: 'c', file: '/x.js' }, { handler: 'd', file: '/x.js' }],
  alreadyOn: [{ handler: 'handleScreenSaver', file: '/y.js' }, { handler: 'handleATLauncherKey', file: MINE }, { handler: 'home', file: '/z.js' }],
};
for (const [name, list] of Object.entries(lists)) {
  const orig = write('orig-' + name + '.json', { configs: { [CFG]: list }, returnValue: true });
  assert.deepStrictEqual(JSON.parse(node(keysJs, [orig, MINE, CFG])), JSON.parse(py(keysPy, [orig, MINE, CFG])), name);
  const offPy = atl.match(/python3 -c "(import json,sys; print[^"]*)"/)[1];
  assert.deepStrictEqual(JSON.parse(node(keysOffJs, [orig])), JSON.parse(py(offPy, [orig])), name + ' off');
}

// ---- apps-watch.sh: apps.json and appicons/ ----
const watch = read('app/tools/apps-watch.sh');
const appsPy = watch.match(/python3 -c '\n([\s\S]*?)\n' "\$DATA"/)[1];
function appsFixture(dir) {
  fs.mkdirSync(path.join(dir, 'custom', 'icons'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'storeicons'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'appicons'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'appicons', 'gone.png'), 'old');
  fs.writeFileSync(path.join(dir, 'custom', 'icons', 'netflix.jpg'), 'mine');
  fs.writeFileSync(path.join(dir, 'storeicons', 'netflix-tile-0123456789.png'), 'tile');
  fs.writeFileSync(path.join(dir, 'storeicons', 'index.json'), JSON.stringify({ netflix: { tile: 'storeicons/netflix-tile-0123456789.png' }, hulu: { tile: 'storeicons/missing.png' } }));
  const apps = path.join(dir, 'apps'); fs.mkdirSync(apps);
  for (const [id, files] of Object.entries({ netflix: ['large.PNG', 'splash.jpg'], hulu: ['icon.webp'], 'com.webos.app.hdmi1': ['hdmi.png'], mid: ['mid.png', 'small.png'] }))
    { fs.mkdirSync(path.join(apps, id)); for (const f of files) fs.writeFileSync(path.join(apps, id, f), id + f); }
  return JSON.stringify({ returnValue: true, apps: [
    { id: 'netflix', title: 'Netflix', visible: true, systemApp: false, folderPath: path.join(apps, 'netflix'), largeIcon: 'large.PNG', icon: 'missing.png', splashBackground: 'splash.jpg', iconColor: '#000000' },
    { id: 'hulu', title: 'Hulu', visible: true, folderPath: path.join(apps, 'hulu'), extraLargeIcon: 'icon.webp', bgImage: 'none.png' },
    { id: 'com.webos.app.hdmi1', title: 'HDMI 1', visible: false, systemApp: true, folderPath: path.join(apps, 'com.webos.app.hdmi1'), icon: path.join(apps, 'com.webos.app.hdmi1', 'hdmi.png') },
    { id: 'mid', title: 'Mid', visible: true, folderPath: path.join(apps, 'mid'), icon: 'small.png', mediumLargeIcon: 'mid.png' },
    { id: 'com.webos.app.hidden', title: 'Hidden', visible: false, folderPath: '/nowhere', icon: 'x.png' },
  ] });
}
const dPy = path.join(tmp, 'py'), dJs = path.join(tmp, 'js');
fs.mkdirSync(dPy); fs.mkdirSync(dJs);
const listPy = JSON.parse(py(appsPy, [dPy], appsFixture(dPy)));
const listJs = JSON.parse(run(process.execPath, [path.join(ROOT, 'app/tools/apps-list.js'), dJs], appsFixture(dJs)));
const sameDir = (s) => JSON.parse(JSON.stringify(s).split(dJs).join(dPy));
assert.deepStrictEqual(sameDir(listJs.apps), listPy.apps);
const icons = (d) => Object.fromEntries(fs.readdirSync(path.join(d, 'appicons')).map((f) => [f, fs.readFileSync(path.join(d, 'appicons', f), 'utf8')]));
assert.deepStrictEqual(icons(dJs), icons(dPy));
assert(!fs.existsSync(path.join(dJs, 'appicons', 'gone.png')));

// ---- storeicons.js: the same tables as storeicons.py, and the Apple TV icon from a page ----
const store = require(path.join(ROOT, 'app/tools/storeicons.js'));
const storePy = read('app/tools/storeicons.py');
const builtinPy = JSON.parse(py(`import importlib.util,json,sys\ns=importlib.util.spec_from_file_location('s',sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)\nprint(json.dumps({'b':m.BUILTIN,'v':m.INDEX_VERSION,'skip':m.SKIP.pattern}))`, [path.join(ROOT, 'app/tools/storeicons.py')]));
assert.deepStrictEqual(store.BUILTIN, builtinPy.b);
assert.strictEqual(store.INDEX_VERSION, builtinPy.v);
assert.strictEqual(store.SKIP.source, builtinPy.skip);
const art = (t, w, h) => `"icon":{"$kind":"Artwork","crop":"bb","template":"${t}/{w}x{h}{c}.{f}","width":${w},"height":${h}`;
const page = `{"adamId":"111",${art('https://x/other.lsr', 1280, 768)}}{"adamId":"222",${art('https://x/phone.png', 1024, 1024)},${art('https://x/own.lsr', 1280, 768)}}`;
assert.strictEqual(store.ownTvIcon(page, '222'), 'https://x/own.lsr');
assert.strictEqual(store.ownTvIcon(page, '333'), null);
assert.strictEqual(store.norm('Disney+ (TV)'), 'disneytv');

// ---- extras/aerial/apply-picks.sh ----
const aerial = read('extras/aerial/apply-picks.sh');
const [aerialJs] = nodeBlocks(aerial), [aerialPy] = heredocs(aerial);
const videos = { assets: [{ id: 'a' }, { id: 'b' }, { id: 'c' }], other: 1 };
const picks = { picks: [{ id: 'c', name: 'C' }, { id: 'z', name: 'Zed' }, { id: 'a', name: 'A' }], sourceType: 'url-4K-HDR' };
const outs = {};
for (const [lang, fn, code] of [['py', py, aerialPy], ['js', node, aerialJs]]) {
  const v = write(lang + '-videos.json', videos), o = write(lang + '-out.json', '{}'), st = write(lang + '-settings.json', { sourceType: 'x', keep: true });
  outs[lang] = { said: fn(code, [v, o, st, write('picks.json', picks)]), out: JSON.parse(fs.readFileSync(o, 'utf8')), settings: JSON.parse(fs.readFileSync(st, 'utf8')) };
}
assert.deepStrictEqual(outs.js, outs.py);

// ---- setup-qml-permissions.js: the same change as the .py, for ATLauncher and for LG's Home id ----
const perm = require(path.join(ROOT, 'scripts/setup-qml-permissions.js'));
const permPy = (manifest, permissions, appId) => JSON.parse(py(`import importlib.util,json,sys
s=importlib.util.spec_from_file_location('r',sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
m.APP_ID=sys.argv[4]
print(json.dumps(m.configuration(json.loads(sys.argv[2]),json.loads(sys.argv[3]))))`, [path.join(ROOT, 'scripts/setup-qml-permissions.py'), JSON.stringify(manifest), JSON.stringify(permissions), appId]));
const installer = { id: perm.APP_ID, version: '1.0.4', roleFilesPrv: ['legacy-private'], roleFilesPub: ['legacy-public'], clientPermissionFiles: ['existing'] };
for (const [manifest, permissions, appId] of [[installer, { [perm.APP_ID]: ['public'] }, perm.APP_ID],
                                               [perm.newManifest('com.webos.app.fullhome'), {}, 'com.webos.app.fullhome']]) {
  const js = perm.configuration(manifest, permissions, undefined, appId);
  assert.deepStrictEqual(js, permPy(manifest, permissions, appId), appId);
  assert.deepStrictEqual(perm.configuration(js[1], js[2], undefined, appId), js, appId + ' twice');
  assert.deepStrictEqual(js[2][appId + '-*'], ['public']);
}

// ---- the timeout probe: each script picks the syntax its timeout accepts ----
const probes = ['app/tools/atlauncher.sh', 'app/tools/apps-watch.sh', 'app/tools/home-redirect.sh']
  .map((p) => read(p).split('\n').find((l) => l.startsWith('if timeout 1 true')));
assert(probes.every((l) => l && l === probes[0]), 'the same probe in every script');
const fake = {
  // GNU coreutils / BusyBox 1.30+: timeout SECS CMD
  gnu: '#!/bin/sh\ncase "$1" in -t) echo "bad option" >&2; exit 125;; esac\nshift; exec "$@"\n',
  // BusyBox 1.29 (webOS 5): timeout [-t SECS] CMD; a number as the command fails
  busybox: '#!/bin/sh\nif [ "$1" = -t ]; then shift 2; exec "$@"; fi\necho "timeout: can\'t execute \'$1\'" >&2; exit 127\n',
};
for (const [kind, script] of Object.entries(fake)) {
  const bin = path.join(tmp, 'bin-' + kind); fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'timeout'), script, { mode: 0o755 });
  const said = execFileSync('sh', ['-c', probes[0] + '\ntmo 10 echo ran'], { encoding: 'utf8', env: { ...process.env, PATH: bin + ':' + process.env.PATH } });
  assert.strictEqual(said.trim(), 'ran', kind);
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log('PASS: Node fallbacks match the Python steps; timeout probe handles both syntaxes');
