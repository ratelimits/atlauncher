import QtQuick 2.12
import "."
import QtQuick.Window 2.12
import "Catalog.js" as Cat
import "Store.js" as Store
import "Tmdb.js" as Tmdb

/* ATLauncher: a Home Screen for LG webOS TVs, inspired by Apple TV, native QtQuick (drawn on the GPU). Runs inside
   main.qml (the TV's WebOSWindow and luna calls) or preview.qml (a desktop window with stubs).
   Geometry: 6 columns of 250x150 icons, 48px gaps, 90px margins, 28px corners, 1.2x focus; Dock glass at
   x 39-1881 / y 784-1012, radius 66; the next row peeks at y 1053. */
Item {
    id: home
    width: 1920
    height: 1080
    focus: true

    // Provided by the host: luna.call(uri, payload, callback(result)) and the launch parameters.
    property var luna: null
    property string appId: 'com.ratelimits.atlauncher'
    property var launchParams: ({})
    property string version: ''
    // Test only ({"art": "4k"}): decode backdrops at 3840x2160 instead of 1920x1080.
    property bool art4k: false
    readonly property bool asHome: appId === Cat.ESCAPE_ID
    // 'tv' (LG webOS) or 'mac' (a desktop build: no LG settings, no installed-app list).
    property string platform: 'tv'
    readonly property bool onTv: platform === 'tv'

    readonly property int cols: Cat.COLS
    readonly property int tileW: 250
    readonly property int gap: 48
    readonly property int marginX: 90
    readonly property int dockTop: 823
    readonly property int gridTop: 1053
    readonly property int rowPitch: 259
    readonly property int cardW: 840
    readonly property int cardGap: 48
    readonly property int barX: 39
    readonly property int barY: 784

    readonly property int tmdbRevealMs: 5000
    readonly property int carouselMs: 9000
    readonly property int shelfDwellMs: 300
    readonly property int longPressMs: 600
    readonly property int repeatMs: 150

    // ---- State ----
    property var apps: []
    property var appById: ({})
    property var candidates: []
    property var installed: null
    property int rev: 0                 // bumped whenever apps / TMDB items change (bindings read it)
    property int selected: 0
    property string mode: 'home'        // home | grid | shelf
    property int shelfApp: 0
    property int page: 0
    property int card: 0
    property int pill: 0
    property bool appView: false
    property bool editing: false
    property string style: 'none'       // none | carousel | row | app (what the Top Shelf shows now)
    property var tmdbItems: ({})
    property string revealedId: ''
    property bool tmdbAsked: false
    property bool cacheFresh: false
    property var prefs: ({})
    property bool liquidGlass: true
    // Settings > Appearance > Icon Size: how big an app's own icon is drawn on its tile (in tile heights).
    readonly property var iconSizes: [{ name: 'Fill', scale: 1.67 }, { name: 'Large', scale: 1.3 }, { name: 'Medium', scale: 1.0 }, { name: 'Small', scale: 0.75 }]
    property int iconSizeIndex: 2   // Medium
    readonly property real iconScale: iconSizes[iconSizeIndex].scale
    function sizeIndex(name) {
        for (var i = 0; i < iconSizes.length; i++) if (iconSizes[i].name === name) return i;
        return 2;   // Medium
    }
    property var shownScene: null
    property bool pointerLive: false
    property bool pointerEnabled: true   // Magic Remote hover (off in scripted previews)
    property double pointerLockUntil: 0

    readonly property int focusIndex: mode === 'shelf' ? -1 : selected
    readonly property bool grid: mode === 'grid'
    readonly property bool carouselFull: mode === 'shelf' && (style === 'carousel' || style === 'app')
    readonly property int deep: grid && row(selected) >= 3 ? (row(selected) - 2) * rowPitch : 0
    property real dockShift: grid ? -723 - deep : carouselFull ? 440 : 0
    property real gridShift: grid ? -694 - deep : carouselFull ? 440 : 0
    Behavior on dockShift { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    Behavior on gridShift { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
    readonly property real rowShade: style === 'row' && !grid ? 0.52 : 0

    function row(i) { return Math.floor(i / cols); }

    // ---- webOS ----
    function call(uri, payload, done) {
        if (luna) luna.call(uri, payload || {}, done || function () {});
    }

    function toast(message) {
        toastText.text = message;
        toastBox.shown = true;
        toastTimer.restart();
    }

    function launch(app) {
        if (app.id === Cat.SETTINGS_ID) { openSettings(); return; }
        if (app.id !== Cat.ESCAPE_ID) Store.set('lastApp', app.id);
        if (app.open) {
            call(app.open, {}, function (r) { if (r && r.returnValue === false) call('luna://com.webos.applicationManager/launch', { id: app.id }); });
            return;
        }
        call('luna://com.webos.applicationManager/launch', { id: app.id }, function (r) {
            if (r && r.returnValue === false) toast(app.name + ' could not be opened' + (r.errorText ? ': ' + r.errorText : '.'));
        });
    }

    // Settings > System > Restart into LG Home: as the Home app, ask home-redirect.sh (it watches for the web
    // version's developer-app id, which nothing else launches) to restart the TV into LG Home. Two presses.
    property double escapeArmed: 0
    function restartIntoLgHome() {
        if (!asHome) { launch({ id: Cat.ESCAPE_ID, name: 'LG Home' }); return; }
        if (Date.now() < escapeArmed) {
            escapeArmed = 0;
            toast('Restarting into LG Home… The restart after that brings ATLauncher back.');
            call('luna://com.webos.applicationManager/launch', { id: Cat.OWN_ID });
        } else {
            escapeArmed = Date.now() + 4000;
            toast('Press OK again to restart the TV into LG Home.');
        }
    }

    function returnToPriorViewing() {
        var prev = Store.get('lastApp', '');
        var app = apps.filter(function (a) { return a.id === prev && a.id !== Cat.ESCAPE_ID; })[0];
        if (app) launch(app); else bumpTile(selected, 'down');
    }

    // ---- TMDB ----
    /* Each user brings their own TMDB API key (free, themoviedb.org/settings/api): Cat.DATA_DIR/tmdb.key on the TV,
       or tmdb.key next to preview.qml on a computer. Without one the Top Shelf shows the apps' own splashes. */
    property string tmdbKey: ''
    readonly property string tmdbNotice: 'This product uses the TMDB API but is not endorsed or certified by TMDB.'
    function loadTmdbKey() {
        [onTv ? 'file://' + Cat.DATA_DIR + '/tmdb.key' : Qt.resolvedUrl('tmdb.key')].forEach(function (url) {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                var key = (xhr.responseText || '').replace(/[^0-9a-fA-F]/g, '');
                if (key.length >= 16) tmdbKey = key;
            };
            xhr.open('GET', url);
            try { xhr.send(); } catch (e) {}
        });
    }
    function loadCache() {
        var cache = Store.get('tmdb', null);
        if (cache && cache.items) {
            Object.keys(cache.items).forEach(function (id) {
                cache.items[id].forEach(function (it) { if (it.logo) it.logo = Tmdb.pngLogo(it.logo); });
            });
            tmdbItems = cache.items;
        }
        return !!cache && Date.now() - cache.ts < Tmdb.TTL;
    }
    function refreshTmdb() {
        if (!tmdbKey) return;
        Tmdb.refresh(tmdbKey, Cat.KNOWN, function (fresh) {
            if (!fresh) return;
            tmdbItems = fresh;
            Store.set('tmdb', { ts: Date.now(), items: fresh });
            rev++;
            render(true);
        });
    }

    function tmdbStyle(i) {
        var app = apps[i];
        return !prefs.tmdbOff && app && app.style && tmdbItems[app.id] && tmdbItems[app.id].length ? app.style : 'none';
    }
    function styleOf(i) { return apps[i] && apps[i].id === revealedId ? tmdbStyle(i) : 'none'; }
    function itemsOf(i) { return (apps[i] && tmdbItems[apps[i].id]) || []; }

    // Each time the Top Shelf moves to an app it shows the app's own splash; after resting there, its shows.
    function armReveal() {
        revealTimer.stop();
        revealedId = '';
        var app = apps[shelfApp];
        if (app && app.tmdb) { revealTimer.index = shelfApp; revealTimer.restart(); }
    }
    function reveal(index) {
        if (index !== shelfApp || !apps[index] || prefs.tmdbOff || (appView && mode === 'shelf')) return;
        revealedId = apps[index].id;
        if (!tmdbAsked && tmdbKey) { tmdbAsked = true; if (!cacheFresh) refreshTmdb(); }
        render(true);
    }

    // Without TMDB: your custom art, else the app's own splash, else its colours (resolved by Catalog.withArt).
    function staticItem(app) {
        var shelf = app.shelf || ['#3a3c46', '#0b0c0f'];
        return typeof shelf === 'string' ? { key: shelf, src: shelf } : { key: 'g:' + shelf.join(','), gradient: shelf };
    }

    function sceneFor(index) {
        var app = apps[index], st = styleOf(index), items = itemsOf(index);
        var item = st === 'carousel' ? items[page % items.length] : st === 'row' ? items[Math.min(card, items.length - 1)] : null;
        if (!item) {
            var s = staticItem(app);
            return { key: s.key, src: s.src || '', gradient: s.gradient || null, item: null, style: st };
        }
        var src = st === 'row' ? item.card : item.backdrop;
        return { key: st + '|' + src, src: src, gradient: null, item: item, logo: st === 'carousel' ? item.logo : '', style: st };
    }

    // ---- Modes and layout ----
    function setMode(next) {
        if (next !== mode) pointerLockUntil = Date.now() + 480;
        mode = next;
    }

    // Apply the derived state: the Top Shelf style, the scene, the carousel timer.
    function render(fresh) {
        var st = mode === 'shelf' && appView ? 'app' : styleOf(shelfApp);
        if (st === 'none' && mode === 'shelf') { mode = 'home'; }
        if (mode !== 'shelf') appView = false;
        st = mode === 'shelf' && appView ? 'app' : styleOf(shelfApp);
        style = st;
        if (fresh) rev++;
        scheduleCarousel();
        if (apps[shelfApp]) backdrop.show(sceneFor(shelfApp));
    }

    function scheduleCarousel() {
        carouselTimer.stop();
        if (settings.open || mode === 'grid' || styleOf(shelfApp) !== 'carousel' || itemsOf(shelfApp).length < 2) return;
        carouselTimer.restart();
    }

    function followFocus() { shelfTimer.restart(); }

    function tileAt(i) { return tileRepeater.itemAt(i); }
    function bumpTile(i, dir) { var t = tileAt(i); if (t) t.bump(dir); }

    function move(dx, dy) {
        var col = selected % cols, next = selected;
        if (dx) {
            if (col + dx < 0 || col + dx >= cols || selected + dx >= apps.length) return bumpTile(selected, dx < 0 ? 'left' : 'right');
            next = selected + dx;
        } else {
            var r = row(selected) + dy, lastRow = row(apps.length - 1);
            if (r < 0 || r > lastRow) return bumpTile(selected, dy < 0 ? 'up' : 'down');
            next = Math.min(r * cols + col, apps.length - 1);
            while (next > r * cols && apps[next].gap) next--;
        }
        if (apps[next].gap) return bumpTile(selected, dx < 0 ? 'left' : dx > 0 ? 'right' : dy < 0 ? 'up' : 'down');
        focusTile(next, dx, dy);
    }

    function focusTile(index, dx, dy) {
        if (index === selected && mode !== 'shelf') return;
        selected = index;
        setMode(row(selected) > 0 ? 'grid' : 'home');
        render();
        var t = tileAt(selected);
        if (t) { if (dx || dy) t.kick(dx || 0, dy || 0); t.land(); }
        followFocus();
    }

    function press() {
        var app = mode === 'shelf' ? apps[shelfApp] : apps[selected];
        if (!app || app.gap) return;
        pressTarget = mode === 'shelf' ? (appView ? 'open' : style === 'row' ? 'card' : (pill === 0 ? 'play' : 'info')) : 'tile';
        pressTimer.app = app;
        pressTimer.restart();
    }
    property string pressTarget: ''
    Timer { id: pressTimer; interval: 110; property var app: null; onTriggered: { home.pressTarget = ''; home.launch(app); } }

    function gridKey(key) {
        if (key === Qt.Key_Left) move(-1, 0);
        else if (key === Qt.Key_Right) move(1, 0);
        else if (key === Qt.Key_Down) move(0, 1);
        else if (key === Qt.Key_Up) {
            if (row(selected) > 0) move(0, -1);
            else if (shelfApp !== selected || styleOf(selected) === 'none') openAppView();
            else {
                pill = 0;
                setMode('shelf');
                render();
                if (styleOf(selected) === 'row') { var c = cardRepeater.itemAt(card); if (c) { c.land(); } }
            }
        } else return false;
        return true;
    }

    // Up on a Dock app whose splash is showing: its name and Open take the screen; its shows don't replace the
    // splash while this is up.
    function openAppView() {
        shelfTimer.stop();
        revealTimer.stop();
        if (shelfApp !== selected) { shelfApp = selected; page = 0; card = 0; }
        revealedId = '';
        appView = true;
        setMode('shelf');
        render();
    }
    function closeAppView() {
        appView = false;
        setMode('home');
        render();
        var t = tileAt(selected); if (t) t.land();
        armReveal();
    }

    function shelfKey(key, back) {
        var n = itemsOf(shelfApp).length;
        if (appView) {
            if (key === Qt.Key_Down || back) closeAppView();
            else if (key === Qt.Key_Left || key === Qt.Key_Right) openPill.bump(key === Qt.Key_Left ? 'left' : 'right');
            else if (key !== Qt.Key_Up) return false;
            return true;
        }
        if (key === Qt.Key_Down || back) { setMode('home'); pill = 0; render(); var t = tileAt(selected); if (t) t.land(); return true; }
        if (styleOf(shelfApp) === 'carousel') {
            if (key === Qt.Key_Left) { if (pill > 0) pill = 0; else if (n > 1) { page = (page - 1 + n) % n; pill = 0; } }
            else if (key === Qt.Key_Right) { if (pill === 0) pill = 1; else if (n > 1) { page = (page + 1) % n; pill = 0; } }
            else if (key !== Qt.Key_Up) return false;
            render();
            return true;
        }
        var c;
        if (key === Qt.Key_Left) {
            if (card > 0) { card--; render(); c = cardRepeater.itemAt(card); if (c) { c.kick(-1); c.land(); } }
            else { c = cardRepeater.itemAt(card); if (c) c.bump('left'); }
        } else if (key === Qt.Key_Right) {
            if (card < n - 1) { card++; render(); c = cardRepeater.itemAt(card); if (c) { c.kick(1); c.land(); } }
            else { c = cardRepeater.itemAt(card); if (c) c.bump('right'); }
        } else if (key !== Qt.Key_Up) return false;
        return true;
    }

    // ---- App list ----
    function storeState() {
        return { order: Store.get('order', null), seen: Store.get('seen', null), hidden: Store.get('hidden', []) };
    }
    function saveOrder() { Store.set('order', apps.filter(Cat.movable).map(function (a) { return a.id; })); }
    function isHidden(id) { return Cat.isHidden(id, storeState()); }
    function setHidden(id, hide) {
        var hidden = Store.get('hidden', []).filter(function (h) { return h !== id; }), seen = Store.get('seen', {}) || {};
        if (hide) hidden.push(id);
        else if (seen[id] === 'hidden') { seen[id] = 'shown'; Store.set('seen', seen); }
        Store.set('hidden', hidden);
    }

    function updateApps() {
        var focusId = apps[selected] && apps[selected].id, shelfId = apps[shelfApp] && apps[shelfApp].id;
        var st = storeState();
        var hadSeen = !!st.seen;
        var r = Cat.arrange(installed, st, [appId, Cat.OWN_ID], { storeIcons: prefs.storeIcons !== false, storeOff: prefs.storeOff || [] });
        if (installed && (st.seen || hadSeen)) Store.set('seen', st.seen);
        apps = r.apps;
        candidates = r.candidates;
        var byId = {};
        apps.forEach(function (a) { byId[a.id] = a; });
        appById = byId;
        var saved = Store.get('order', []) || [];
        if (installed && apps.some(function (a) { return Cat.movable(a) && saved.indexOf(a.id) < 0; })) saveOrder();
        // The tiles follow the list (rebuilt only when it changed).
        var ids = apps.map(function (a) { return a.id; }), same = ids.length === appModel.count;
        for (var i = 0; same && i < ids.length; i++) same = appModel.get(i).aid === ids[i];
        if (!same) { appModel.clear(); ids.forEach(function (id) { appModel.append({ aid: id }); }); }
        var last = Math.max(0, apps.length - 1);
        selected = ids.indexOf(focusId) >= 0 ? ids.indexOf(focusId) : Math.min(selected, last);
        shelfApp = ids.indexOf(shelfId) >= 0 ? ids.indexOf(shelfId) : Math.min(shelfApp, last);
        if (mode !== 'shelf') mode = row(selected) > 0 ? 'grid' : 'home';
        render(true);
    }

    // The installed-app list: tools/apps-watch.sh (root, started at boot) follows SAM's list and writes it as
    // apps.json into Cat.DATA_DIR; read it here every 10 s (parsed only when it changed).
    property string appsText: ''
    function readApps() {
        if (!onTv) return;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var text = xhr.responseText;
            if (!text || text === appsText) return;
            appsText = text;
            var r;
            try { r = JSON.parse(text); } catch (e) { return; }
            if (!r || !r.apps) return;
            var map = {};
            r.apps.forEach(function (a) { map[a.id] = a; });
            installed = map;
            updateApps();
        };
        xhr.open('GET', 'file://' + Cat.DATA_DIR + '/apps.json');
        try { xhr.send(); } catch (e) {}
    }
    Timer { interval: 10000; repeat: true; running: home.onTv; onTriggered: home.readApps() }

    // ---- Edit mode (hold OK on an icon) ----
    function startEditing() {
        if (!Cat.movable(apps[selected])) { bumpTile(selected, 'up'); return; }
        editing = true;
        var t = tileAt(selected); if (t) t.land();
    }
    function finishEditing() {
        editing = false;
        saveOrder();
        var t = tileAt(selected); if (t) t.land();
    }
    function editKey(key, back) {
        if (back) { finishEditing(); return true; }
        var col = selected % cols, to = -1, dir = '';
        if (key === Qt.Key_Left) { dir = 'left'; if (col > 0) to = selected - 1; }
        else if (key === Qt.Key_Right) { dir = 'right'; if (col < cols - 1 && selected + 1 < apps.length) to = selected + 1; }
        else if (key === Qt.Key_Up) { dir = 'up'; if (selected >= cols) to = selected - cols; }
        else if (key === Qt.Key_Down) { dir = 'down'; if (row(selected) < row(apps.length - 1)) to = Math.min(selected + cols, apps.length - 1); }
        else return false;
        if (to >= 0 && !Cat.movable(apps[to])) to = -1;
        if (to < 0) { bumpTile(selected, dir); return true; }
        var list = apps.slice();
        list.splice(to, 0, list.splice(selected, 1)[0]);
        apps = list;
        appModel.move(selected, to, 1);
        selected = to;
        setMode(row(selected) > 0 ? 'grid' : 'home');
        render();
        saveOrder();
        return true;
    }

    // ---- Settings ----
    function setPref(name, value) { var p = prefs; p[name] = value; prefs = p; Store.set('prefs', p); }
    function onOff(on) { return on ? 'On' : 'Off'; }

    function pageFor(id) {
        if (id === 'top') return { title: 'Settings', rows: [
            { label: 'Apps', page: 'apps', glyph: 'apps', note: 'Show or hide apps on the Home Screen, and rearrange them.' },
            { label: 'Top Shelf', page: 'shelf', glyph: 'shelf', note: 'What appears above the Dock.' },
            { label: 'Appearance', page: 'look', glyph: 'look', note: 'How the Dock and app icons look.' }
        ].concat(onTv ? [
            { label: 'TV Settings', glyph: 'tv', note: 'LG’s quick settings panel: picture, sound and the rest, with All Settings at the bottom.',
              act: function () {
                  call('luna://com.webos.service.systemUIManager/launch', { appId: 'com.webos.app.quicksettings' }, function (r) {
                      if (r && r.returnValue === false) launch({ id: 'com.palm.app.settings', name: 'TV Settings' });
                  });
              } },
            { label: 'System', page: 'system', glyph: 'system', note: asHome ? 'Restart into LG Home, and about ATLauncher.' : 'Open LG Home, and about ATLauncher.' }
        ] : [
            { label: 'About', value: 'ATLauncher' + (version ? ' ' + version : ''), glyph: 'info', note: 'A Home Screen for this Mac. ' + tmdbNotice }
        ]) };
        if (id === 'apps') {
            var rows = [{ label: 'Rearrange Apps', glyph: 'move', note: 'Move apps with the arrows, then press OK. You can also hold OK on any app on the Home Screen.',
                act: function () {
                    closeSettings(true);
                    var first = apps.map(Cat.movable).indexOf(true);
                    if (first < 0) return;
                    openAt(first);
                    startEditing();
                } }];
            candidates.forEach(function (app) {
                rows.push({ label: app.name, value: isHidden(app.id) ? 'Hidden' : 'Shown', page: 'app:' + app.id,
                    image: app.tile || app.icon || '', generic: !app.tile, color: app.color,
                    note: 'Show or hide it, choose its icon, or quit or delete it.' });
            });
            return { title: 'Apps', rows: rows };
        }
        if (id.indexOf('app:') === 0) return appPage(id.slice(4));
        if (id === 'shelf') return { title: 'Top Shelf', rows: [
            { label: 'Movies and Shows', value: tmdbKey ? onOff(!prefs.tmdbOff) : 'No API key', glyph: 'shelf',
              note: tmdbKey ? 'Each app shows its own splash first; after 5 seconds on Netflix, Prime Video, Disney+, Hulu or Apple TV, its popular shows from TMDB. Off keeps the splashes. ' + tmdbNotice
                            : 'Popular shows need your own free TMDB API key in ' + Cat.DATA_DIR + '/tmdb.key (see the README). Until then each app shows its own splash.',
              act: function () { setPref('tmdbOff', !prefs.tmdbOff); if (prefs.tmdbOff) render(true); else armReveal(); refreshSettings(); } }
        ] };
        if (id === 'look') return { title: 'Appearance', rows: [
            { label: 'Liquid Glass Dock', value: onOff(liquidGlass), glyph: 'look',
              note: 'The Dock is a slab of glass: its rounded edge bends the picture behind it and catches the light. Off keeps a plain clear edge.',
              act: function () { liquidGlass = !liquidGlass; setPref('liquidGlass', liquidGlass); refreshSettings(); } },
            { label: 'App Store Icons', value: onOff(prefs.storeIcons !== false), glyph: 'apps',
              note: 'Use each app\u2019s Apple TV icon from the App Store (or its iPhone icon), fetched by the TV and kept on it. Off uses the icons LG apps come with.',
              act: function () { setPref('storeIcons', prefs.storeIcons === false); updateApps(); refreshSettings(); } },
            { label: 'Icon Size', value: iconSizes[iconSizeIndex].name, glyph: 'apps',
              note: 'How big each app\u2019s own icon is on its tile: Fill covers the tile, Small shows the whole icon on its own colour. Press OK to change.',
              act: function () { iconSizeIndex = (iconSizeIndex + 1) % iconSizes.length; setPref('iconSizeName', iconSizes[iconSizeIndex].name); refreshSettings(); } }
        ] };
        return { title: 'System', rows: [
            asHome ? { label: 'Restart into LG Home', glyph: 'restart', note: 'Restarts the TV into LG’s own Home screen. The restart after that brings ATLauncher back.', act: restartIntoLgHome }
                   : { label: 'Open LG Home', glyph: 'restart', note: 'Opens LG’s own Home screen.', act: restartIntoLgHome },
            { label: 'About', value: 'ATLauncher' + (version ? ' ' + version : ''), glyph: 'info',
              note: 'A Home Screen for this TV, inspired by Apple TV. Not affiliated with LG, Apple or the apps shown. ' + tmdbNotice +
                    ' github.com/ratelimits/atlauncher' }
        ] };
    }

    // Settings > Apps > <app>: Home Screen (shown / hidden), App Store Icon, Quit App (while it runs), Delete App.
    property var runningIds: []
    property string deleteArmed: ''
    property double deleteArmedUntil: 0
    function refreshRunning() {
        call('luna://com.webos.applicationManager/running', {}, function (r) {
            runningIds = ((r && r.running) || []).map(function (a) { return a.id; });
            if (settings.open) refreshSettings();
        });
    }
    function appPage(id) {
        var app = candidates.filter(function (a) { return a.id === id; })[0];
        if (!app) return { title: 'Apps', rows: [] };
        var pic = { image: app.tile || app.icon || '', generic: !app.tile, color: app.color };
        function row(r) { for (var k in pic) r[k] = pic[k]; return r; }
        var hidden = isHidden(app.id), storeOff = (prefs.storeOff || []).indexOf(app.id) >= 0;
        var rows = [
            row({ label: 'Home Screen', value: hidden ? 'Hidden' : 'Shown',
                  note: hidden ? 'Not on the Home Screen. Press OK to show it.' : 'On the Home Screen. Press OK to hide it.',
                  act: function () { setHidden(app.id, !hidden); updateApps(); refreshSettings(); } }),
            row({ label: 'App Store Icon', value: !app.storeTile ? 'Not available' : storeOff ? 'Off' : 'On',
                  note: !app.storeTile ? 'This app has no Apple TV version on the App Store, so it keeps its own icon.'
                      : storeOff ? 'Using the app\u2019s own icon. Press OK to use its Apple TV icon from the App Store.'
                                 : 'Using its Apple TV icon from the App Store. Press OK to use the app\u2019s own icon.',
                  act: function () {
                      if (!app.storeTile) return;
                      var list = (prefs.storeOff || []).filter(function (x) { return x !== app.id; });
                      if (!storeOff) list.push(app.id);
                      setPref('storeOff', list); updateApps(); refreshSettings();
                  } })
        ];
        if (runningIds.indexOf(app.id) >= 0 && !app.builtin) rows.push(row({ label: 'Quit App', note: app.name + ' is running. Press OK to quit it.',
            act: function () {
                call('luna://com.webos.applicationManager/closeByAppId', { id: app.id }, function (r) {
                    toast(r && r.returnValue === false ? app.name + ' could not be quit.' : app.name + ' quit.');
                    refreshRunning();
                });
            } }));
        if (deletable(app)) {
            var armed = deleteArmed === app.id && Date.now() < deleteArmedUntil;
            rows.push(row({ label: 'Delete App', value: armed ? 'Press OK again' : '',
                note: 'Deletes ' + app.name + ' and its data from this TV.',
                act: function () {
                    if (deleteArmed === app.id && Date.now() < deleteArmedUntil) {
                        deleteArmed = '';
                        deleteApp(app);
                        settings.stack.pop();
                        refreshSettings();
                    } else {
                        deleteArmed = app.id;
                        deleteArmedUntil = Date.now() + 4000;
                        refreshSettings();
                    }
                } }));
        }
        return { title: app.name, rows: rows };
    }

    QtObject {
        id: settings
        property bool open: false
        property var stack: []
    }
    function refreshSettings() {
        var level = settings.stack[settings.stack.length - 1];
        var pg = pageFor(level.page);
        level.index = Math.min(level.index, pg.rows.length - 1);
        settingsView.page = pg;
        settingsView.index = level.index;
    }
    function openSettings() {
        settings.stack = [{ page: 'top', index: 0 }];
        settings.open = true;
        carouselTimer.stop();
        refreshSettings();
    }
    function closeSettings(instant) {
        if (!settings.open) return;
        settings.open = false;
        settingsFade.instant = !!instant;
        render();
    }
    function settingsKey(key, back) {
        var level = settings.stack[settings.stack.length - 1], n = settingsView.page.rows.length;
        if (back) {
            if (settings.stack.length > 1) { settings.stack.pop(); refreshSettings(); } else closeSettings();
        } else if (key === Qt.Key_Up || key === Qt.Key_Down) {
            var to = level.index + (key === Qt.Key_Up ? -1 : 1);
            if (to < 0 || to >= n) settingsView.bump(key === Qt.Key_Up ? 'up' : 'down');
            else { level.index = to; settingsView.index = to; }
        } else if (isOk(key)) {
            var info = settingsView.page.rows[level.index];
            if (!info) return true;
            settingsView.pressRow();
            if (info.page) {
                settings.stack.push({ page: info.page, index: 0 });
                if (info.page === 'apps' || info.page.indexOf('app:') === 0) refreshRunning();
                refreshSettings();
            }
            else if (info.act) info.act();
            else settingsView.bump('right');
        } else if (key !== Qt.Key_Left && key !== Qt.Key_Right) return false;
        return true;
    }

    // ---- Launch / relaunch ----
    function launchFocus(p) {
        for (var i = 0; p && p.focus && i < apps.length; i++) if (apps[i].id === p.focus) return i;
        return -1;
    }
    function openAt(index) {
        selected = index; shelfApp = index; page = 0; card = 0; pill = 0; appView = false;
        armReveal();
        setMode(row(index) > 0 ? 'grid' : 'home');
        render();
        var t = tileAt(selected); if (t) t.land();
    }
    /* The Home key (and homekey.js's Settings / Input buttons) relaunch ATLauncher with new parameters.
       Home coming back from another app returns to the app you were on; Home pressed while ATLauncher is already in
       front goes to the first app (row 0, column 0). `away`: ATLauncher's window lost focus since the last relaunch
       (an app opened over it); set by the host. */
    property bool away: false
    function relaunch(p) {
        p = p || {};
        launchParams = p;
        var wasAway = away;
        away = false;
        if (editing) { editing = false; saveOrder(); }
        if (p.activateType === 'settings') { if (!settings.open) openSettings(); return; }
        if (settings.open) closeSettings(true);
        var f = launchFocus(p);
        openAt(f >= 0 ? f : wasAway ? selected : 0);
    }

    // ---- Input ----
    function isOk(key) { return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select; }
    // LG's remote sends its own Back code (WebOS.Key_webOS_Back, passed in by main.qml) once the window takes Back.
    property var backKeys: []
    function isBack(key) { return key === Qt.Key_Escape || key === Qt.Key_Back || key === Qt.Key_Backspace || backKeys.indexOf(key) >= 0; }

    property double lastMove: 0
    /* OK: opens on release (tvOS); held on an app, it opens the app menu. LG's remote can repeat a held OK as release
       + press pairs, so a release only counts once no press follows within okGap (otherwise a held OK looked like a
       tap and opened the app). After an OK that did something on press (the menu, Settings, edit mode), everything
       until the real release is ignored (okSuppress), so repeats never act twice. */
    property bool okDown: false
    property bool okSuppress: false
    Timer {
        id: holdTimer
        interval: home.longPressMs
        onTriggered: {
            if (!home.okDown) return;
            home.okDown = false;
            home.okSuppress = true;
            home.pressTarget = '';
            home.openAppMenu();
        }
    }
    Timer {
        id: okGap
        interval: 70
        onTriggered: {
            holdTimer.stop();
            if (home.okSuppress) { home.okSuppress = false; return; }
            if (home.okDown) { home.okDown = false; home.pressTarget = ''; home.press(); }
        }
    }

    Keys.onPressed: event.accepted = keyDown(event.key, event.isAutoRepeat)
    Keys.onReleased: event.accepted = keyUp(event.key, event.isAutoRepeat)

    function keyDown(key, repeat) {
        var back = isBack(key), handled = true;
        pointerLive = false;
        if (isOk(key)) {
            if (okGap.running) { okGap.stop(); return true; }      // a repeat pair: still held
            if (okSuppress || repeat || okDown) return true;
            if (appMenu.shown) { okSuppress = true; menuActivate(); return true; }
            if (settings.open) { okSuppress = true; settingsKey(key, false); return true; }
            if (editing) { okSuppress = true; finishEditing(); return true; }
            okDown = true;
            if (mode !== 'shelf') { pressTarget = 'held'; holdTimer.restart(); }
            return true;
        }
        if (appMenu.shown) return menuKey(key, back);
        if (settings.open) return settingsKey(key, back);
        if (repeat && Date.now() - lastMove < repeatMs) return true;
        if (editing) handled = editKey(key, back);
        else if (mode === 'shelf') handled = shelfKey(key, back);
        else if (back) {
            // tvOS: Back from the grid returns to the Dock; Back from the Dock returns to what was playing.
            if (row(selected) > 0) focusTile(selected % cols); else returnToPriorViewing();
        } else handled = gridKey(key);
        if (handled) lastMove = Date.now();
        else console.log('ATLauncher: unhandled key', key);
        return handled;
    }
    function keyUp(key, repeat) {
        if (!isOk(key)) return false;
        okGap.restart();
        return true;
    }

    // ---- App menu (hold OK on an app): Quit App (if running), Edit Home Screen, Delete App ----
    property var menuApp: null
    property string menuStage: ''          // 'actions' | 'confirm'
    function deletable(app) {
        var info = installed && installed[app.id];
        return !!info && !app.builtin && !Cat.isFixed(app) && !info.systemApp && app.id.indexOf('com.webos.') !== 0 && app.id !== 'airplay';
    }
    function openAppMenu() {
        var app = apps[selected];
        if (!app || app.gap) return;
        menuApp = app;
        call('luna://com.webos.applicationManager/running', {}, function (r) {
            var running = ((r && r.running) || []).some(function (a) { return a.id === app.id; });
            var rows = [];
            if (running && !app.builtin) rows.push({ id: 'quit', label: 'Quit App', glyph: 'quit' });
            rows.push({ id: 'edit', label: 'Edit Home Screen', glyph: 'edit' });
            if (deletable(app)) rows.push({ id: 'delete', label: 'Delete App', glyph: 'delete', red: true });
            showMenu('actions', '', rows);
        });
    }
    function showMenu(stage, title, rows) {
        menuStage = stage;
        appMenu.title = title;
        appMenu.rows = rows;
        appMenu.index = 0;
        // Beside the icon (as drawn focused, 1.2x): on its right, top edges aligned; on its left only when the right
        // has no room (the last column). Kept on screen at the bottom.
        var t = tileAt(selected), p = t ? t.mapToItem(home, t.width / 2, t.height / 2) : Qt.point(960, 540);
        var halfW = 125 * 1.2, halfH = 75 * 1.2, gapX = 30;
        var right = p.x + halfW + gapX;
        appMenu.x = right + appMenu.width <= 1920 - 40 ? right : p.x - halfW - gapX - appMenu.width;
        appMenu.y = Math.max(40, Math.min(1080 - 30 - appMenu.height, p.y - halfH));
        appMenu.shown = true;
    }
    function closeMenu() { appMenu.shown = false; menuApp = null; }
    function menuKey(key, back) {
        if (back) { closeMenu(); return true; }
        if (key === Qt.Key_Up) appMenu.index = Math.max(0, appMenu.index - 1);
        else if (key === Qt.Key_Down) appMenu.index = Math.min(appMenu.rows.length - 1, appMenu.index + 1);
        return true;
    }
    function menuActivate() {
        var row = appMenu.rows[appMenu.index], app = menuApp;
        if (!row || !app) return closeMenu();
        if (row.id === 'quit') {
            closeMenu();
            call('luna://com.webos.applicationManager/closeByAppId', { id: app.id }, function (r) {
                toast(r && r.returnValue === false ? app.name + ' could not be quit.' : app.name + ' quit.');
            });
        } else if (row.id === 'edit') {
            closeMenu();
            startEditing();
        } else if (row.id === 'delete') {
            showMenu('confirm', 'Delete “' + app.name + '”? Its data on this TV is deleted too.',
                     [{ id: 'confirm', label: 'Delete', glyph: 'delete', red: true }, { id: 'cancel', label: 'Cancel', glyph: 'quit' }]);
        } else if (row.id === 'confirm') {
            closeMenu();
            deleteApp(app);
        } else closeMenu();
    }
    function deleteApp(app) {
        var info = installed && installed[app.id];
        var dev = !!info && (info.folderPath || '').indexOf('/media/developer/') === 0;
        call(dev ? 'luna://com.webos.appInstallService/dev/remove' : 'luna://com.webos.appInstallService/remove', { id: app.id }, function (r) {
            if (r && r.returnValue === false) { toast(app.name + ' could not be deleted' + (r.errorText ? ': ' + r.errorText : '.')); return; }
            toast('Deleting ' + app.name + '…');
            appsRefresh.restart();
        });
    }
    // apps-watch.sh rewrites apps.json after an uninstall; read it a few times rather than waiting for the poll.
    Timer { id: appsRefresh; interval: 3000; repeat: true; property int n: 0; onTriggered: { home.readApps(); if (++n >= 4) { n = 0; stop(); } } }

    // ---- Timers ----
    Timer { id: revealTimer; interval: home.tmdbRevealMs; property int index: -1; onTriggered: home.reveal(index) }
    Timer { id: carouselTimer; interval: home.carouselMs; onTriggered: { var n = home.itemsOf(home.shelfApp).length; if (n) { home.page = (home.page + 1) % n; home.pill = 0; home.render(); } } }
    Timer {
        id: shelfTimer
        interval: home.shelfDwellMs
        onTriggered: {
            if (home.shelfApp === home.selected) return;
            home.shelfApp = home.selected;
            home.page = 0;
            home.card = 0;
            home.armReveal();
            home.render();
        }
    }
    Timer { id: toastTimer; interval: 3200; onTriggered: toastBox.shown = false }

    // ==================================================================================================================
    // Scene

    Backdrop {
        id: backdrop
        artSize: home.art4k ? Qt.size(3840, 2160) : Qt.size(1920, 1080)
        frostLevel: home.grid || home.style === 'row' || settings.open ? 1 : 0
        covered: settingsView.covering
        onShown: home.shownScene = scene
        Behavior on frostLevel { NumberAnimation { duration: 400 } }
    }

    Item {
        id: homeLayer
        anchors.fill: parent
        visible: !settingsView.covering

        Rectangle {
            anchors.fill: parent
            color: 'black'
            opacity: home.grid ? 0.42 : home.style === 'row' ? 0.52 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        // Legibility scrims: top 20% and bottom 42%.
        Rectangle {
            width: 1920; height: 216
            gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28) } GradientStop { position: 1; color: 'transparent' } }
        }
        Rectangle {
            y: 1080 - 454; width: 1920; height: 454
            gradient: Gradient { GradientStop { position: 0; color: 'transparent' } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.34) } }
        }
        // Full-screen carousel / app view: darken the left for the title and buttons.
        Rectangle {
            width: 1190; height: 1080
            opacity: home.carouselFull ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 0.645; color: Qt.rgba(0, 0, 0, 0.18) }
                GradientStop { position: 1; color: 'transparent' }
            }
        }

        // ---- Clock + avatar pill ----
        Item {
            id: status
            x: 1920 - 50 - width
            y: 50
            width: statusRow.width + 33
            height: 60
            opacity: home.grid || home.carouselFull ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Glass {
                anchors.fill: parent
                screenX: status.x
                screenY: status.y
                sharpA: backdrop.back.sharp; frostA: backdrop.back.frost
                sharpB: backdrop.front.sharp; frostB: backdrop.front.frost
                mix: backdrop.mix
                radius: 30; edge: 18; liquid: 0
                frosted: backdrop.frostLevel
                dark: 0.18 + home.rowShade * 0.82
            }
            Row {
                id: statusRow
                x: 24
                height: parent.height
                spacing: 14
                Text {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 25
                    color: 'white'
                    function update() {
                        var d = new Date(), h = d.getHours() % 12 || 12, m = d.getMinutes();
                        text = h + ':' + (m < 10 ? '0' : '') + m + (d.getHours() < 12 ? ' AM' : ' PM');
                    }
                    Component.onCompleted: update()
                    Timer { interval: 15000; repeat: true; running: true; onTriggered: clock.update() }
                }
                Rectangle {
                    width: 42; height: 42; radius: 21
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    gradient: Gradient { GradientStop { position: 0; color: '#8e8e93' } GradientStop { position: 1; color: '#48484a' } }
                    Glyph { anchors.centerIn: parent; width: 26; height: 26; name: 'user'; color: 'white' }
                }
            }
        }

        // ---- Home: show title (carousel apps) and the "swipe up" chevron ----
        Item {
            x: 90; y: 70; width: 620; height: 220
            opacity: home.mode === 'home' && home.style === 'carousel' && home.shownScene && home.shownScene.item ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            TitleMark { anchors.fill: parent; scene: home.shownScene; maxW: 620; maxH: 220 }
        }
        // The chevron rides with the Dock (it sits just above it), and leaves quickly: fixed in place during a slow fade
        // it hung over the grid as the Dock slid up past it.
        Glyph {
            id: chevron
            readonly property bool on: home.mode === 'home' && home.style !== 'row'
            x: 937; y: 750 + home.dockShift; width: 46; height: 46
            name: 'chevron-up'
            symbolScale: 0.9
            opacity: on ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: chevron.on ? 300 : 120 } }
        }

        // Magic Remote: clicking the show art above the Dock opens the full-screen carousel (or the app view), like Up.
        MouseArea {
            width: 1920; height: 770
            enabled: home.mode === 'home' && home.style !== 'row' && !home.editing
            onClicked: {
                if (home.shelfApp !== home.selected || home.styleOf(home.selected) === 'none') { home.openAppView(); return; }
                home.pill = 0;
                home.setMode('shelf');
                home.render();
            }
        }

        // ---- Sectioned Top Shelf ("Top Shows") ----
        Item {
            width: 1920; height: 760
            readonly property bool on: home.style === 'row' && !home.grid
            opacity: on ? 1 : 0
            transform: Translate { y: parent.on ? 0 : 20; Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } } }
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 350 } }
            Text {
                x: 90; y: 100
                text: 'Top Shows'
                font.family: Style.font; font.weight: Font.DemiBold; font.pixelSize: 44
                color: Qt.rgba(1, 1, 1, 0.62)
            }
            Item {
                x: -Math.max(0, Math.min(home.card, home.itemsOf(home.shelfApp).length - 1) - 1) * (home.cardW + home.cardGap)
                Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
                Repeater {
                    id: cardRepeater
                    model: (home.rev, home.style === 'row' ? home.itemsOf(home.shelfApp) : [])
                    delegate: Card {
                        x: home.marginX + index * (home.cardW + home.cardGap)
                        y: 176
                        item: modelData
                        focused: home.mode === 'shelf' && home.style === 'row' && index === Math.min(home.card, cardRepeater.count - 1)
                        pressed: focused && home.pressTarget === 'card'
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: home.pointerEnabled
                            onPositionChanged: {
                                home.pointerLive = true;
                                if (home.card !== index && Date.now() > home.pointerLockUntil) { home.card = index; home.setMode('shelf'); home.render(); }
                            }
                            onClicked: { home.card = index; home.setMode('shelf'); home.render(); home.press(); }
                        }
                    }
                }
            }
        }

        // ---- Full-screen carousel: logo, synopsis, Play / More Info ----
        Column {
            x: 90
            y: 1080 - 120 - height
            spacing: 0
            readonly property bool on: home.mode === 'shelf' && home.style === 'carousel'
            opacity: on ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: parent.on ? 0 : 30; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } } }
            Behavior on opacity { NumberAnimation { duration: 400 } }
            TitleMark { width: 700; height: 240; scene: home.shownScene; maxW: 700; maxH: 240; twoLines: true }
            Item { width: 1; height: 20 }
            Text {
                width: 900
                visible: text !== ''
                text: home.shownScene && home.shownScene.item ? home.shownScene.item.overview : ''
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 29
                lineHeight: 38; lineHeightMode: Text.FixedHeight
                color: Qt.rgba(1, 1, 1, 0.85)
            }
            Item { width: 1; height: 34 }
            Row {
                spacing: 20
                Repeater {
                    model: [{ label: 'Play', icon: true }, { label: 'More Info', icon: false }]
                    Pill {
                        label: modelData.label
                        playIcon: modelData.icon
                        focused: home.style === 'carousel' && home.carouselFull && home.pill === index
                        pressed: focused && home.pressTarget === (index === 0 ? 'play' : 'info')
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: home.pointerEnabled
                            onEntered: if (home.mode === 'shelf' && home.pointerLive) home.pill = index
                            onPositionChanged: home.pointerLive = true
                            onClicked: if (home.mode === 'shelf') { home.pill = index; home.press(); }
                        }
                    }
                }
            }
        }

        // ---- App view: the app's name and Open ----
        Column {
            x: 90
            y: 1080 - 120 - height
            readonly property bool on: home.mode === 'shelf' && home.style === 'app'
            opacity: on ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: parent.on ? 0 : 30; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } } }
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Text {
                width: 900
                elide: Text.ElideRight
                text: home.apps[home.shelfApp] ? home.apps[home.shelfApp].name : ''
                font.family: Style.font; font.weight: Font.Bold; font.pixelSize: 76
                color: 'white'
            }
            Item { width: 1; height: 34 }
            Pill {
                id: openPill; label: 'Open'; focused: home.style === 'app'; pressed: home.pressTarget === 'open'
                MouseArea { anchors.fill: parent; onClicked: if (home.mode === 'shelf' && home.appView) home.press() }
            }
        }

        // TMDB attribution, small, while a show is open full-screen (Up on a show).
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 90
            y: 1080 - 56 - height
            text: 'Uses the TMDB API \u00b7 not endorsed or certified by TMDB'
            font.family: Style.font; font.pixelSize: 18
            color: Qt.rgba(1, 1, 1, 0.5)
            opacity: home.mode === 'shelf' && home.shownScene && home.shownScene.item ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Carousel page dots.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 1080 - 64 - 10
            spacing: 12
            opacity: home.mode === 'shelf' && home.style === 'carousel' ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Repeater {
                model: (home.rev, home.style === 'carousel' && home.itemsOf(home.shelfApp).length > 1 ? home.itemsOf(home.shelfApp).length : 0)
                Rectangle {
                    width: 10; height: 10; radius: 5; antialiasing: true
                    color: index === home.page % Math.max(1, home.itemsOf(home.shelfApp).length) ? 'white' : Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        // ---- Dock glass (moves with the Dock row) ----
        Shadow {
            x: home.barX - blur
            y: home.barY + home.dockShift - blur + 16
            shapeW: 1842; shapeH: 228; radius: 66; blur: 36; dy: 0; strength: 0.26
            visible: home.liquidGlass
        }
        Glass {
            id: dockGlass
            x: home.barX
            y: home.barY + home.dockShift
            width: 1842
            height: 228
            sharpA: backdrop.back.sharp; frostA: backdrop.back.frost
            sharpB: backdrop.front.sharp; frostB: backdrop.front.frost
            mix: backdrop.mix
            radius: 66
            edge: home.liquidGlass ? 36 : 24
            liquid: home.liquidGlass ? 1 : 0
            // Frosted wherever the backdrop is (it follows the same 400 ms fade).
            frosted: backdrop.frostLevel
            dark: home.grid ? 0.42 : home.rowShade
            Behavior on dark { NumberAnimation { duration: 400 } }
        }

        // ---- App icons: the Dock row and the grid below it ----
        ListModel { id: appModel }
        Repeater {
            id: tileRepeater
            model: appModel
            delegate: Tile {
                id: tileItem
                readonly property int r: Math.floor(index / home.cols)
                app: (home.rev, home.appById[aid] || ({}))
                visible: !app.gap
                x: home.marginX + (index % home.cols) * (home.tileW + home.gap)
                y: r === 0 ? home.dockTop + home.dockShift : home.gridTop + (r - 1) * home.rowPitch + home.gridShift
                inGrid: r > 0
                focused: index === home.focusIndex
                editing: home.editing
                iconScale: home.iconScale
                pressed: focused && (home.pressTarget === 'tile' || home.pressTarget === 'held')
                Behavior on x { enabled: home.editing; NumberAnimation { duration: 320; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: home.pointerEnabled
                    property point last: Qt.point(-1, -1)
                    onPositionChanged: {
                        var g = mapToItem(null, mouse.x, mouse.y);
                        if (g.x === last.x && g.y === last.y) return;
                        last = g;
                        home.pointerLive = true;
                        if (!home.editing && Date.now() > home.pointerLockUntil && !home.settingsOpenNow()) home.focusTile(index);
                    }
                    onClicked: {
                        if (home.settingsOpenNow()) return;
                        if (home.editing) { home.finishEditing(); return; }
                        home.focusTile(index);
                        home.press();
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            text: 'Move the app, then press OK'
            font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 24
            color: Qt.rgba(1, 1, 1, 0.8)
            opacity: home.editing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }
    function settingsOpenNow() { return settings.open; }

    // LG Magic Remote: the scroll wheel moves one row per notch (throttled).
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        property double at: 0
        onWheel: {
            if (Date.now() - at < 280 || !wheel.angleDelta.y || home.editing) return;
            at = Date.now();
            var down = wheel.angleDelta.y < 0;
            if (settings.open) { home.settingsKey(down ? Qt.Key_Down : Qt.Key_Up, false); return; }
            if (home.mode === 'shelf') { if (down) home.shelfKey(Qt.Key_Down, false); return; }
            home.gridKey(down ? Qt.Key_Down : Qt.Key_Up);
        }
    }

    // ---- App menu (hold OK on an app) ----
    AppMenu {
        id: appMenu
        backdrop: backdrop
        onHovered: index = row
        onActivated: { index = row; home.menuActivate(); }
    }

    // ---- Settings ----
    SettingsView {
        id: settingsView
        frost: backdrop.front.frost
        pointerEnabled: home.pointerEnabled
        onHovered: if (settings.open) { var level = settings.stack[settings.stack.length - 1]; level.index = row; settingsView.index = row; }
        onClicked: if (settings.open) { onHovered(row); home.settingsKey(Qt.Key_Return, false); }
        property bool covering: false
        opacity: settings.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { id: settingsFade; property bool instant: false; duration: instant ? 0 : 300 } }
        onOpacityChanged: covering = opacity >= 1
    }

    // ---- Toast ----
    Rectangle {
        id: toastBox
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: shown ? 60 : 30
        width: toastText.width + 68
        height: 68
        radius: 30
        color: Qt.rgba(40 / 255, 40 / 255, 46 / 255, 0.92)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Text {
            id: toastText
            anchors.centerIn: parent
            font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 25
            color: 'white'
        }
    }

    /* One-time import of an arrangement, e.g. from another launcher: DATA_DIR/import.json with
       { "id": "<any new value>", "order": [app ids], "hidden": [app ids], "prefs": {...} }. Applied once per "id". */
    function importArrangement() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var m;
            try { m = JSON.parse(xhr.responseText); } catch (e) { return; }
            if (!m || !m.id || Store.get('importId', '') === m.id) return;
            Store.set('importId', m.id);
            if (m.order) Store.set('order', m.order);
            if (m.hidden) Store.set('hidden', m.hidden);
            if (m.prefs) {
                var p = prefs; for (var k in m.prefs) p[k] = m.prefs[k];
                prefs = p; Store.set('prefs', p);
                liquidGlass = p.liquidGlass !== false;
                iconSizeIndex = sizeIndex(p.iconSizeName);
            }
            toast('Imported your Home Screen arrangement.');
            updateApps();
        };
        xhr.open('GET', onTv ? 'file://' + Cat.DATA_DIR + '/import.json' : Qt.resolvedUrl('import.json'));
        try { xhr.send(); } catch (e) {}
    }

    // Start-up.
    Component.onCompleted: {
        loadTmdbKey();
        prefs = Store.get('prefs', {}) || {};
        liquidGlass = prefs.liquidGlass !== false;
        iconSizeIndex = sizeIndex(prefs.iconSizeName);
        cacheFresh = loadCache();
        updateApps();
        readApps();
        importArrangement();
        var p = launchParams || {};
        if (launchFocus(p) >= 0) openAt(launchFocus(p)); else openAt(0);
        if (p.activateType === 'settings') openSettings();
    }
}
