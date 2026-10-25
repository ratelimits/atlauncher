import QtQuick 2.12
import Eos.Window 0.1
import WebOSServices 1.0
import WebOS.Global 1.0

/* ATLauncher on the TV: run by LG's qml-runner, which sets `appId` and `params` (the launch parameters) for this
   file. The window is a normal app card; luna calls go through LG's QML Service. */
WebOSWindow {
    id: win
    width: 1920
    height: 1080
    visible: true
    color: 'black'
    appId: runner.id || 'com.ratelimits.atlauncher'
    windowType: '_WEBOS_WINDOW_TYPE_CARD'

    // qml-runner updates `params` on a relaunch (the Home key, homekey.js's Settings / Input buttons).
    Runner { id: runner }
    // ATLauncher handles Back itself (Settings pages, the grid, the shelf). Without this LG treats Back as "leave the
    // app" and offers to exit it, as for any app that doesn't take the key (StarfishAccessControlPolicy).
    // Set at runtime (declaring windowProperties in place stopped the window loading), and never fatal.
    property string backPolicy: ''
    Component.onCompleted: {
        try {
            var props = windowProperties || {};
            props['_WEBOS_ACCESS_POLICY_KEYS_BACK'] = 'true';
            windowProperties = props;
            backPolicy = 'set';
        } catch (e) { backPolicy = 'failed: ' + e; }
    }
    // Another app came over ATLauncher: the next Home press returns to the app that was focused (Home.relaunch).
    onActiveChanged: if (!active) home.away = true
    property var launchParams: runner.launchParams || ({})
    onLaunchParamsChanged: if (ready) { home.relaunch(parsed(launchParams)); maybeBench(parsed(launchParams)); }
    property bool ready: false

    function parsed(p) {
        try { if (typeof p === 'string') p = JSON.parse(p || '{}'); } catch (e) { p = {}; }
        return p || {};
    }


    // luna.call(uri, payload, done): uri is luna://<service>/<method>.
    Service {
        id: service
        appId: win.appId
        property var pending: ({})
        onResponse: {
            var cb = pending[token];
            if (!cb) return;
            delete pending[token];
            var r = null;
            try { r = JSON.parse(payload); } catch (e) {}
            cb(r);
        }
    }
    QtObject {
        id: luna
        function call(uri, payload, done) {
            var m = /^(luna:\/\/[^\/]+)(\/.*)$/.exec(uri);
            if (!m) return;
            var token = service.call(m[1], m[2], JSON.stringify(payload || {}));
            if (done) service.pending[token] = done;
        }
    }

    // Test mode ({"bench": 1}): walk the Dock (150 ms a move) for 12 s, then show the frame rate.
    property var gaps: []
    property double last: 0
    property bool counting: false
    onFrameSwapped: {
        if (!counting) return;
        var now = Date.now();
        if (last > 0) gaps.push(now - last);
        last = now;
    }
    Timer {
        id: bench
        interval: 150
        repeat: true
        property int n: 0
        property int dir: 1
        onTriggered: {
            if (n === 0) { win.gaps = []; win.last = 0; win.counting = true; }
            n++;
            if (home.selected + dir < 0 || home.selected + dir > 5) dir = -dir;
            home.keyDown(dir > 0 ? Qt.Key_Right : Qt.Key_Left, false);
            if (n < 80) return;
            stop();
            win.counting = false;
            var g = win.gaps.slice().sort(function (a, b) { return a - b; });
            var total = g.reduce(function (a, b) { return a + b; }, 0);
            benchText.text = (stage.render4k ? 'app 4K' : 'app 1080p') + ', ' + (home.art4k ? 'art 4K' : 'art 1080p') + ':  fps ' + (1000 * g.length / total).toFixed(1) + '  p50 ' + g[Math.floor(g.length / 2)] + ' ms  p95 ' +
                g[Math.floor(g.length * 0.95)] + ' ms  max ' + g[g.length - 1] + ' ms  (' + g.length + ' frames)';
        }
    }
    function maybeBench(p) {
        if (!p || !p.bench) return;
        // Test only: {"render": "4k"} draws everything at 3840x2160 off-screen and scales it down to the 1920x1080
        // graphics plane (the TV's compositor size); {"art": "4k"} decodes backdrops at 3840x2160.
        stage.render4k = p.render === '4k';
        home.art4k = p.art === '4k';
        bench.n = 0;
        benchText.text = 'measuring\u2026';
        bench.start();
    }

    Item {
        id: stage
        width: 1920
        height: 1080
        property bool render4k: false
        layer.enabled: render4k
        layer.textureSize: Qt.size(3840, 2160)
        layer.smooth: true

    Home {
        id: home
        luna: luna
        appId: win.appId
        launchParams: win.parsed(win.launchParams)
        version: '1.0.0'
        backKeys: [WebOS.Key_webOS_Back]
        focus: true
        Component.onCompleted: { forceActiveFocus(); win.ready = true; win.maybeBench(win.parsed(win.launchParams)); }
    }
    }
    Text {
        id: benchText
        x: 60; y: 40
        visible: text !== ''
        color: 'white'
        style: Text.Outline
        styleColor: 'black'
        font.pixelSize: 36
    }
}
