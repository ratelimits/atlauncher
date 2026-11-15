/* apps-watch.sh's app list step in Node, for TVs without python3 (webOS 5 has Node 8 built in). The same output as
   the Python in apps-watch.sh: SAM's listApps reply on stdin, ATLauncher's apps.json on stdout, each visible app's
   icon and splash copied into appicons/. Usage: luna-send ... listApps '{}' | node apps-list.js /var/lib/atlauncher
   Node 8: no syntax newer than ES2017. */
'use strict';
var fs = require('fs'), path = require('path');

var data = process.argv[2];
var icons = path.join(data, 'appicons');
var KEYS = ['id', 'title', 'iconColor', 'folderPath', 'visible', 'systemApp'];
var IMAGE = /\.(png|jpg|jpeg|webp)$/i;
// Hidden LG apps ATLauncher still shows as tiles, with the TV's own icons.
var SHOWN_HIDDEN = ['com.webos.app.hdmi1', 'com.webos.app.hdmi2', 'com.webos.app.hdmi3', 'com.webos.app.hdmi4', 'airplay'];

function isFile(p) { try { return fs.statSync(p).isFile(); } catch (e) { return false; } }
function size(p) { return fs.statSync(p).size; }

/* Copy the first existing image among `fields` to appicons/<name>.<ext>; return its path relative to data. */
function copy(app, fields, name) {
    for (var i = 0; i < fields.length; i++) {
        var src = app[fields[i]];
        if (typeof src !== 'string' || !IMAGE.test(src)) continue;
        if (src.charAt(0) !== '/') src = path.join(app.folderPath || '', src);
        if (!isFile(src)) continue;
        var dst = path.join(icons, name + path.extname(src).toLowerCase());
        if (!isFile(dst) || size(dst) !== size(src)) {
            fs.writeFileSync(dst + '.tmp', fs.readFileSync(src));
            fs.renameSync(dst + '.tmp', dst);
        }
        return path.relative(data, dst);
    }
    return null;
}

function custom(kind, appId) {
    var exts = ['.png', '.jpg', '.jpeg'];
    for (var i = 0; i < exts.length; i++) {
        var p = path.join('custom', kind, appId + exts[i]);
        if (isFile(path.join(data, p))) return p;
    }
    return null;
}

function main(input) {
    if (!fs.existsSync(icons)) fs.mkdirSync(icons);
    var apps = JSON.parse(input).apps || [];
    var store = {};
    try { store = JSON.parse(fs.readFileSync(path.join(data, 'storeicons', 'index.json'), 'utf8')); } catch (e) {}
    var out = [], keep = {};
    apps.forEach(function (a) {
        var entry = {};
        KEYS.forEach(function (k) { entry[k] = a[k] === undefined ? null : a[k]; });
        if (a.visible || SHOWN_HIDDEN.indexOf(a.id) >= 0) {
            entry.tileIcon = copy(a, ['extraLargeIcon', 'largeIcon', 'mediumLargeIcon', 'icon'], a.id);
            entry.tileBg = copy(a, ['splashBackground', 'bgImage'], a.id + '-bg');
            [entry.tileIcon, entry.tileBg].forEach(function (p) { if (p) keep[path.basename(p)] = true; });
        }
        entry.customIcon = custom('icons', a.id);
        entry.customArt = custom('art', a.id);
        var s = store[a.id] || {};
        [['tile', 'storeTile'], ['icon', 'storeIcon']].forEach(function (kf) {
            if (s[kf[0]] && isFile(path.join(data, s[kf[0]]))) entry[kf[1]] = s[kf[0]];
        });
        out.push(entry);
    });
    fs.readdirSync(icons).forEach(function (f) {   // uninstalled apps
        if (!keep[f]) fs.unlinkSync(path.join(icons, f));
    });
    process.stdout.write(JSON.stringify({ ts: Date.now(), apps: out }) + '\n');
}

var chunks = [];
process.stdin.on('data', function (c) { chunks.push(c); });
process.stdin.on('end', function () { main(Buffer.concat(chunks).toString('utf8')); });
