/* storeicons.py in Node, for TVs without python3 (webOS 5 has Node 8 built in). Same behaviour, files and exit
   codes; see storeicons.py for what it does. apps-watch.sh runs this one only where python3 is missing.
     node storeicons.js                  fetch what is missing or stale
     node storeicons.js --refetch <id>   download that app's icon again
   Exit 3: apps.json should be rewritten to carry the new icons. Node 8: no syntax newer than ES2017.
   Keep BUILTIN, SKIP and INDEX_VERSION in step with storeicons.py (tests/node-fallbacks.cjs checks). */
'use strict';
var fs = require('fs'), path = require('path'), https = require('https'), url = require('url');
var crypto = require('crypto'), childProcess = require('child_process');

var DATA = '/var/lib/atlauncher';
var OUT = path.join(DATA, 'storeicons');
var INDEX = path.join(OUT, 'index.json');
var UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) ' +
         'Version/17.0 Safari/605.1.15';
var HIT_DAYS = 30, MISS_DAYS = 7;
var INDEX_VERSION = 5;

var BUILTIN = {
    'netflix': 363590051, 'amazon': 545519333, 'com.disney.disneyplus-prod': 1446075923, 'hulu': 376510438,
    'com.apple.appletv': 1174078549, 'youtube.leanback.v4': 544007664, 'com.wbd.stream': 1666653815,
    'com.peacock.tv': 1508186374, 'com.apple.applemusic': 1108187390, 'com.microsoft.xbox': 736179781,
    'com.sonyliv2.tvapp': 587794258, 'com.domain.xstreamplay': 1000556753
};
var SKIP = /^(com\.webos\.|com\.palm\.|com\.lge\.|airplay$|org\.webosbrew\.|com\.ratelimits\.atlauncher$)/;

function tvCountry() {
    try {
        var out = childProcess.execFileSync('luna-send', ['-n', '1', 'luna://com.webos.settingsservice/getSystemSettings',
            '{"category":"option","keys":["smartServiceCountryCode2"]}'], { encoding: 'utf8', timeout: 10000 });
        var m = /"smartServiceCountryCode2"\s*:\s*"([A-Za-z]{2})"/.exec(out);
        return m ? m[1].toLowerCase() : 'us';
    } catch (e) {
        return 'us';
    }
}

var COUNTRY = 'us';

function stores() { return COUNTRY !== 'us' ? [COUNTRY, 'us'] : ['us']; }

function HttpError(code) { this.code = code; this.message = 'HTTP Error ' + code; }
HttpError.prototype.toString = function () { return this.message; };

function get(u, binary, hops) {
    hops = hops || 0;
    return new Promise(function (resolve, reject) {
        var o = url.parse(u);
        o.headers = { 'User-Agent': UA };
        var req = https.get(o, function (res) {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && hops < 5) {
                res.resume();
                resolve(get(url.resolve(u, res.headers.location), binary, hops + 1));
                return;
            }
            if (res.statusCode !== 200) { res.resume(); reject(new HttpError(res.statusCode)); return; }
            var chunks = [];
            res.on('data', function (c) { chunks.push(c); });
            res.on('end', function () { var b = Buffer.concat(chunks); resolve(binary ? b : b.toString('utf8')); });
        });
        req.setTimeout(20000, function () { req.abort(); });
        req.on('error', reject);
    });
}

function norm(s) { return String(s || '').toLowerCase().replace(/[^a-z0-9]/g, ''); }

/* The App Store id for an app name, only if a result's name starts with it (or is it). */
async function search(title) {
    var want = norm(title);
    if (want.length < 3) return null;
    var countries = stores();
    for (var c = 0; c < countries.length; c++) {
        var q = 'term=' + encodeURIComponent(title) + '&entity=software&country=' + countries[c] + '&limit=8';
        var results = JSON.parse(await get('https://itunes.apple.com/search?' + q)).results || [];
        for (var i = 0; i < results.length; i++) {
            var name = norm(results[i].trackName);
            if (name === want || name.indexOf(want) === 0) return results[i].trackId;
        }
    }
    return null;
}

var ICON = /"icon":\{"\$kind":"Artwork","crop":"[^"]*","template":"([^"]+?\.lsr)\/\{w\}x\{h\}\{c\}\.\{f\}","width":(\d+),"height":(\d+)/;

/* The app's own Apple TV icon (a 5:3 .lsr template) from the page's embedded data: the icon inside the entry that
   carries its adamId, searching only up to the next app's entry. */
function ownTvIcon(page, storeId) {
    var re = new RegExp('"adamId":"' + storeId + '"', 'g'), m;
    while ((m = re.exec(page))) {
        var end = m.index + m[0].length;
        var next = new RegExp('"adamId":"(?!' + storeId + '")', 'g');
        next.lastIndex = end;
        var n = next.exec(page);
        var t = ICON.exec(page.slice(end, n ? n.index : end + 6000));
        if (t && Math.abs(Number(t[2]) / Number(t[3]) - 5 / 3) < 0.02) return t[1];
    }
    return null;
}

/* Download the Apple TV tile. Returns {tile: path}, or {} when the app has no Apple TV version. */
async function fetchTile(storeId, appId) {
    var tv = null, countries = stores();
    for (var c = 0; c < countries.length; c++) {
        try {
            tv = ownTvIcon(await get('https://apps.apple.com/' + countries[c] + '/app/id' + storeId + '?platform=tv'), storeId);
        } catch (e) {
            if (!(e instanceof HttpError) || e.code !== 404) throw e;
            continue;   // not sold in this country's store
        }
        if (tv) break;
    }
    return tv ? { tile: await save(tv + '/500x300bb.png', appId, 'tile') } : {};
}

function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

/* Save as <app id>-<kind>-<content hash>.png, removing that app's older picture of this kind. */
async function save(u, appId, kind) {
    var data = await get(u, true);
    if (data.slice(0, 4).toString('hex') !== '89504e47') throw new Error('not a PNG');
    var name = appId + '-' + kind + '-' + crypto.createHash('sha1').update(data).digest('hex').slice(0, 10) + '.png';
    var old = new RegExp('^' + escapeRe(appId) + '-' + kind + '(-[0-9a-f]{10})?\\.png$');
    fs.readdirSync(OUT).forEach(function (f) { if (f !== name && old.test(f)) fs.unlinkSync(path.join(OUT, f)); });
    var p = path.join(OUT, name);
    fs.writeFileSync(p + '.tmp', data);
    fs.renameSync(p + '.tmp', p);
    return path.relative(DATA, p);
}

function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { return null; } }
function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

async function main() {
    if (!fs.existsSync(OUT)) fs.mkdirSync(OUT);
    COUNTRY = tvCountry();
    var appsJson = readJson(path.join(DATA, 'apps.json'));
    if (!appsJson || !appsJson.apps) return 0;
    var apps = appsJson.apps;
    var overrides = readJson(path.join(DATA, 'store-ids.json')) || {};
    var index = readJson(INDEX) || {};
    if (index._version !== INDEX_VERSION || (index._country || 'us') !== COUNTRY)
        index = { _version: INDEX_VERSION, _country: COUNTRY };
    if (process.argv[2] === '--refetch' && process.argv[3]) delete index[process.argv[3]];
    var now = Date.now() / 1000, changed = false;
    for (var i = 0; i < apps.length; i++) {
        var a = apps[i], appId = a.id || '';
        if (!a.visible || a.systemApp || SKIP.test(appId)) continue;
        if (Object.prototype.hasOwnProperty.call(overrides, appId) && overrides[appId] === null) {
            if (index[appId] !== undefined) { delete index[appId]; changed = true; }
            continue;
        }
        var wanted = overrides[appId] || BUILTIN[appId] || null;
        var old = index[appId] || {};
        var ageDays = (now - (old.ts || 0)) / 86400;
        if (Object.keys(old).length && (wanted === null || old.storeId === wanted) &&
                ageDays < ((old.tile || old.icon) ? HIT_DAYS : MISS_DAYS))
            continue;
        var entry = { ts: now, storeId: null };
        try {
            var storeId = wanted || await search(a.title || appId);
            entry.storeId = storeId;
            if (storeId) Object.assign(entry, await fetchTile(storeId, appId));
        } catch (e) {
            entry.error = String(e).slice(0, 120);
        }
        index[appId] = entry;
        changed = true;
        await sleep(1000);
    }
    // Pictures no app refers to any more (a replaced or dropped icon).
    var used = {};
    Object.keys(index).forEach(function (k) {
        var e = index[k];
        if (e && typeof e === 'object') used[path.basename(e.tile || e.icon || '')] = true;
    });
    fs.readdirSync(OUT).forEach(function (f) { if (/\.png$/.test(f) && !used[f]) fs.unlinkSync(path.join(OUT, f)); });
    if (changed) {
        fs.writeFileSync(INDEX + '.tmp', JSON.stringify(index, null, 1));
        fs.renameSync(INDEX + '.tmp', INDEX);
    }
    return changed ? 3 : 0;
}

if (require.main === module) {
    main().then(function (code) { process.exit(code); }, function (e) { console.error(e); process.exit(1); });
} else {
    module.exports = { norm: norm, ownTvIcon: ownTvIcon, BUILTIN: BUILTIN, SKIP: SKIP, INDEX_VERSION: INDEX_VERSION };
}
