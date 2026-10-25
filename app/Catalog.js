.pragma library
/* Apps ATLauncher knows (display names, TMDB providers, the Top Shelf style), and the Home Screen arrangement rules.
   An app's tile is its Apple TV icon from the App Store (storeicons.py, optional) or its own webOS icon (IconTile; the
   TV's own icons for its inputs, Internet, App Store and AirPlay) and its Top Shelf is the bundled splash in art/ for
   the popular apps, else its own splash, both copied from the TV by tools/apps-watch.sh into DATA_DIR. Your own art in
   DATA_DIR/custom/icons (500x300 tiles) and DATA_DIR/custom/art (1920x1080 splashes), named <app id>.png|jpg, is
   used first.
   The first six apps form the Dock; only Dock apps show TMDB shows. */

var COLS = 6;

var OWN_ID = 'com.ratelimits.atlauncher';
var APP_DIR = '/media/developer/apps/usr/palm/applications/' + OWN_ID;
var DATA_DIR = '/var/lib/atlauncher';
var SETTINGS_ID = 'atlauncher.settings';
var ESCAPE_ID = 'com.webos.app.home';

var KNOWN = [
    { id: 'netflix', name: 'Netflix', shelf: 'art/netflix.png', tmdb: 8, style: 'carousel' },
    { id: 'amazon', name: 'Prime Video', shelf: 'art/amazon.png', tmdb: 9, style: 'row' },
    { id: 'com.disney.disneyplus-prod', name: 'Disney+', shelf: 'art/com.disney.disneyplus-prod.png', tmdb: 337, style: 'carousel' },
    { id: 'hulu', name: 'Hulu', shelf: 'art/hulu.png', tmdb: 15, style: 'row' },
    { id: 'com.apple.appletv', name: 'Apple TV', shelf: 'art/com.apple.appletv.png', tmdb: 350, style: 'carousel' },
    { id: 'youtube.leanback.v4', name: 'YouTube', shelf: 'art/youtube.leanback.v4.png' },
    { id: 'com.wbd.stream', name: 'Max', shelf: 'art/com.wbd.stream.jpg' },
    { id: 'com.peacock.tv', name: 'Peacock', shelf: 'art/com.peacock.tv.jpg' },
    { id: 'com.apple.applemusic', name: 'Music', shelf: 'art/com.apple.applemusic.png' },
    { id: 'com.microsoft.xbox', name: 'Xbox', shelf: 'art/com.microsoft.xbox.png' },
    { id: 'com.webos.app.discovery', name: 'App Store' },
    { id: 'com.webos.app.browser', name: 'Internet' },
    // LG's AirPlay & HomeKit screen, a hidden system app. Launching it alone only starts the receiver;
    // airplay.service/showAirplayPage brings up its AirPlay page.
    { id: 'airplay', name: 'AirPlay', shelf: 'art/airplay.png', builtin: true,
      open: 'luna://airplay.service/showAirplayPage' },
    { id: 'com.webos.app.hdmi1', name: 'HDMI 1', builtin: true },
    { id: 'com.webos.app.hdmi2', name: 'HDMI 2', builtin: true },
    { id: 'com.webos.app.hdmi3', name: 'HDMI 3', builtin: true },
    { id: 'com.webos.app.hdmi4', name: 'HDMI 4', builtin: true },
    { id: 'org.webosbrew.hbchannel', name: 'Homebrew' },
    // Built into ATLauncher, not a webOS app: opens the Settings screen.
    { id: SETTINGS_ID, name: 'Settings', tile: 'icons/atlauncher.settings.png', shelf: ['#6e6e73', '#1c1c1e'], builtin: true }
];

// The permanent bottom row (in this order).
var FIXED_IDS = ['com.webos.app.hdmi1', 'com.webos.app.hdmi2', 'com.webos.app.hdmi3', 'com.webos.app.hdmi4',
                 'org.webosbrew.hbchannel', SETTINGS_ID];
var RENAMED = { 'com.webos.app.tinybrowser': 'com.webos.app.browser' };

function isFixed(app) { return !!app && FIXED_IDS.indexOf(app.id) >= 0; }
function movable(app) { return !!app && !app.gap && !isFixed(app); }
function knownApp(id) { for (var i = 0; i < KNOWN.length; i++) if (KNOWN[i].id === id) return KNOWN[i]; return null; }
function dataUrl(path) { return 'file://' + DATA_DIR + '/' + path; }

/* An app as the Home Screen draws it: the catalog entry (if any) plus what the TV says about it. `tile` is a
   full-bleed 5:3 picture; otherwise `icon` (the app's own icon) is drawn on `color`. `shelf` is a splash picture
   or a [from, to] gradient. */
function withArt(base, info, opts) {
    var app = {};
    for (var k in base) app[k] = base[k];
    info = info || {};
    opts = opts || {};
    if (!app.name) app.name = info.title || app.id;
    // Tile: your custom art, else (App Store Icons on, and not turned off for this app) its Apple TV tile, else its
    // own LG icon. `storeTile` says whether an Apple TV tile exists (Settings > Apps shows it).
    app.storeTile = !!info.storeTile;
    if (info.customIcon) app.tile = dataUrl(info.customIcon);
    else if (opts.storeIcons && info.storeTile && (opts.storeOff || []).indexOf(app.id) < 0) app.tile = dataUrl(info.storeTile);
    if (!app.tile && info.tileIcon) app.icon = dataUrl(info.tileIcon);
    app.color = info.iconColor || app.color || '#3a3c46';
    if (info.customArt) app.shelf = dataUrl(info.customArt);
    else if (!app.shelf && info.tileBg) app.shelf = dataUrl(info.tileBg);
    if (!app.shelf) app.shelf = [app.color, '#0b0c0f'];
    return app;
}

/* Known apps that are installed, then other installed apps (new installs at the end), in the saved arrangement; the
   last movable row is padded with gaps so the permanent row starts at the left. store: { order, seen, hidden }. */
function arrange(installed, store, ownIds, opts) {
    var byId = {}, pool = [];
    KNOWN.forEach(function (a) {
        if (a.builtin || !installed || installed[a.id]) pool.push(withArt(a, installed && installed[a.id], opts));
    });
    if (installed) {
        store.seen = store.seen || {};
        Object.keys(installed).forEach(function (id) {
            var info = installed[id];
            if (info.systemApp || !info.visible || ownIds.indexOf(id) >= 0 || knownApp(id)) return;
            if (!store.seen[id]) store.seen[id] = 'shown';
            pool.push(withArt({ id: id }, info, opts));
        });
    }
    pool.forEach(function (a) { byId[a.id] = a; });
    var order = (store.order || []).map(function (id) { return RENAMED[id] || id; }).filter(function (id) { return byId[id]; });
    var all = order.map(function (id) { return byId[id]; }).concat(pool.filter(function (a) { return order.indexOf(a.id) < 0; }));
    var candidates = all.filter(function (a) { return !isFixed(a); });
    var others = candidates.filter(function (a) { return !isHidden(a.id, store); });
    var fixed = FIXED_IDS.filter(function (id) { return byId[id]; }).map(function (id) { return byId[id]; });
    for (var g = 0; others.length % COLS; g++) others.push({ id: '__gap' + g, name: '', gap: true, shelf: ['#000', '#000'] });
    return { apps: others.concat(fixed), candidates: candidates };
}

function isHidden(id, store) {
    return (store.hidden || []).indexOf(id) >= 0 || (store.seen && store.seen[id] === 'hidden');
}
