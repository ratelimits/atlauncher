#!/usr/bin/env node
/* setup-qml-permissions.py in Node, for TVs without Python 3 (webOS 5 has Node 8 built in). Run as root on the TV:
     node setup-qml-permissions.js          repair ATLauncher's own QML app role (the same change as the .py)
     node setup-qml-permissions.js --home   also add a role for LG's Home app id (webOS 5's com.webos.app.fullhome),
                                            which ATLauncher runs under when atlauncher.sh mounts it as the Home app
   Opt-in, like the .py: nothing runs this for you. Each role is an app-id role with public API access only, the same
   as the .py adds. LG's Home id gets its own manifest in /var/luna-service2-dev/manifests.d (fullhome's system role
   is matched by its program file, /usr/bin/com.webos.app.fullhome, which ATLauncher is not); nothing on the system
   partition is changed. Backups go to /var/lib/atlauncher/backups/; a failed update restores the original files.
   Where the bus has no addOneManifest (webOS 5), the hub is reloaded with ls-control scan-services. */
'use strict';
var fs = require('fs'), path = require('path'), childProcess = require('child_process');

var APP_ID = 'com.ratelimits.atlauncher';
var HOME_IDS = ['com.webos.app.home', 'com.webos.app.fullhome'];
var BASE = '/var/luna-service2-dev';

function unique(list) { return list.filter(function (v, i) { return list.indexOf(v) === i; }); }

/* The same result as configuration() in setup-qml-permissions.py, for any app id. */
function configuration(manifest, permissions, base, appId) {
    base = base || BASE;
    appId = appId || APP_ID;
    var rolePath = path.join(base, 'roles.d', appId + '.app.json');
    var name = appId + '-*';
    var role = { appId: appId, type: 'regular', allowedNames: [name],
                 permissions: [{ service: name, outbound: ['*'] }] };
    var updated = JSON.parse(JSON.stringify(manifest));
    updated.roleFiles = unique((manifest.roleFiles || []).concat([rolePath]));
    var clients = JSON.parse(JSON.stringify(permissions));
    // Public API access suffices for the normal app launch API. Do not elevate the app.
    clients[name] = unique((clients[name] || []).concat(['public']));
    return [role, updated, clients];
}

/* A new manifest for an app id the developer installer never registered (LG's Home id). */
function newManifest(appId, base) {
    base = base || BASE;
    return { id: appId + '.atlauncher', version: '1.0.0',
             clientPermissionFiles: [path.join(base, 'client-permissions.d', appId + '.app.json')] };
}

function luna(method, file) {
    var out = childProcess.execFileSync('luna-send', ['-n', '1', 'luna://com.webos.service.bus/' + method,
        JSON.stringify({ path: file, prefix: '' })], { encoding: 'utf8', timeout: 15000, stdio: ['inherit', 'pipe', 'pipe'] });
    var reply = JSON.parse(out);
    if (!reply.returnValue) throw new Error(out);
    return reply;
}

function unload(file) { try { luna('removeOneManifest', file); return true; } catch (e) { return false; } }

function reload(file) {
    try { luna('addOneManifest', file); return 'addOneManifest'; } catch (e) {
        childProcess.execFileSync('ls-control', ['scan-services'], { timeout: 30000, stdio: 'ignore' });
        return 'ls-control scan-services';
    }
}

function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
function stamp() {
    var d = new Date(), z = function (n) { return (n < 10 ? '0' : '') + n; };
    return d.getFullYear() + z(d.getMonth() + 1) + z(d.getDate()) + '-' + z(d.getHours()) + z(d.getMinutes()) + z(d.getSeconds());
}
function mkdirp(d) { if (!fs.existsSync(d)) { mkdirp(path.dirname(d)); fs.mkdirSync(d); } }

function homeId() {
    var out = '';
    try {
        out = childProcess.execFileSync('luna-send', ['-n', '1', 'luna://com.webos.settingsservice/getSystemSettings',
            '{"category":"general","keys":["defaultApps"]}'], { encoding: 'utf8', timeout: 15000 });
    } catch (e) {}
    var m = /"home"\s*:\s*"([^"]+)"/.exec(out);
    return m && HOME_IDS.indexOf(m[1]) >= 0 ? m[1] : null;
}

function repair(appId, backup) {
    var manifestPath = path.join(BASE, 'manifests.d', appId + '.json');
    var clientPath = path.join(BASE, 'client-permissions.d', appId + '.app.json');
    var rolePath = path.join(BASE, 'roles.d', appId + '.app.json');
    var registered = fs.existsSync(manifestPath);
    if (!registered && appId === APP_ID) throw new Error('ATLauncher is not installed as a developer app: ' + manifestPath);
    var manifest = registered ? readJson(manifestPath) : newManifest(appId);
    var permissions = fs.existsSync(clientPath) ? readJson(clientPath) : {};
    var result = configuration(manifest, permissions, BASE, appId);
    var paths = [rolePath, manifestPath, clientPath];
    var existed = paths.map(function (p) { return fs.existsSync(p); });
    var saved = function (p) { return path.join(backup, path.basename(path.dirname(p)) + '-' + path.basename(p)); };
    paths.forEach(function (p, i) { if (existed[i]) fs.writeFileSync(saved(p), fs.readFileSync(p)); });
    // Unload before changing the files: the hub reads the old manifest to remove it.
    if (registered) unload(manifestPath);
    try {
        [[rolePath, result[0]], [clientPath, result[2]], [manifestPath, result[1]]].forEach(function (pv) {
            mkdirp(path.dirname(pv[0]));
            fs.writeFileSync(pv[0], JSON.stringify(pv[1], null, 2) + '\n');
        });
        return reload(manifestPath);
    } catch (e) {
        paths.forEach(function (p, i) {
            if (existed[i]) fs.writeFileSync(p, fs.readFileSync(saved(p)));
            else if (fs.existsSync(p)) fs.unlinkSync(p);
        });
        if (registered) reload(manifestPath);
        throw e;
    }
}

function main() {
    var ids = [APP_ID];
    if (process.argv.indexOf('--home') >= 0) {
        var home = homeId();
        if (!home) throw new Error("Could not read the TV's Home app (defaultApps.home)");
        if (home === 'com.webos.app.home') console.log('LG Home here is com.webos.app.home: no extra role is needed.');
        else ids.push(home);
    }
    var backup = path.join('/var/lib/atlauncher/backups', 'qml-permissions-' + stamp());
    mkdirp(backup);
    ids.forEach(function (id) {
        var how = repair(id, backup);
        console.log('QML application role loaded for ' + id + ' (' + how + ').');
    });
    console.log('Backup: ' + backup);
}

if (require.main === module) {
    try { main(); } catch (e) { console.error(String(e.message || e)); process.exit(1); }
} else {
    module.exports = { configuration: configuration, newManifest: newManifest, APP_ID: APP_ID };
}
