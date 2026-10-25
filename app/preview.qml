import QtQuick 2.12
import QtQuick.Window 2.12

/* Desktop preview (qmlscene preview.qml): Home in a window scaled to fit, luna calls logged instead of sent.
   Scripted runs for checking layouts: QML_PREVIEW_STEPS="keys:Right,Right wait:800 shot:/path.png ..." —
   steps run in order, then the preview quits. */
Window {
    id: win
    width: 1920 / 2
    height: 1080 / 2
    visible: true
    color: 'black'


    QtObject {
        id: luna
        function call(uri, payload, done) {
            console.log('luna', uri, JSON.stringify(payload));
            if (done) done({ returnValue: true });
        }
    }

    Item {
        width: 1920
        height: 1080
        scale: win.width / 1920
        transformOrigin: Item.TopLeft
        Home {
            id: home
            luna: luna
            appId: 'com.ratelimits.atlauncher'
            version: 'preview'
            pointerEnabled: !Qt.application.arguments.some(function (a) { return a.indexOf('--steps=') === 0; })
            focus: true
        }
    }

    // ---- Scripted steps ----
    property var steps: []
    function keyCode(name) {
        return { Left: Qt.Key_Left, Right: Qt.Key_Right, Up: Qt.Key_Up, Down: Qt.Key_Down, Ok: Qt.Key_Return, Back: Qt.Key_Escape }[name];
    }
    Timer {
        id: runner
        interval: 10
        onTriggered: {
            if (!win.steps.length) { Qt.quit(); return; }
            var step = win.steps.shift(), kind = step.split(':')[0], arg = step.slice(kind.length + 1);
            interval = 10;
            if (kind === 'wait') interval = parseInt(arg, 10);
            else if (kind === 'keys') {
                arg.split(',').forEach(function (k) { driver.queue.push(k); });
                driver.start();
                interval = arg.split(',').length * 180 + 50;
            } else if (kind === 'js') { eval(arg); }
            else if (kind === 'menu') {
                // menu:3 = Quit / Edit / Delete (a running app), menu:2 = Edit / Delete, beside the selected app.
                var rows = [{ id: 'edit', label: 'Edit Home Screen', glyph: 'edit' }, { id: 'delete', label: 'Delete App', glyph: 'delete', red: true }];
                if (arg === '3') rows.unshift({ id: 'quit', label: 'Quit App', glyph: 'quit' });
                home.menuApp = home.apps[home.selected];
                home.showMenu('actions', '', rows);
                interval = 500;
            }
            else if (kind === 'shot') {
                var path = arg;
                // Continue only once the frame is saved (an occluded window renders no frames on macOS).
                home.grabToImage(function (r) { r.saveToFile(path); console.log('saved', path); runner.start(); });
                return;
            }
            start();
        }
    }
    Timer {
        id: driver
        interval: 180
        repeat: true
        property var queue: []
        onTriggered: {
            if (!queue.length) { stop(); return; }
            var k = queue.shift();
            if (k === 'Hold') { home.openAppMenu(); return; }
            var code = win.keyCode(k);
            // Straight into Home's key handlers (qmlscene has no key injection from scripts).
            home.keyDown(code, false);
            home.keyUp(code, false);
        }
    }
    Component.onCompleted: {
        var env = Qt.application.arguments.filter(function (a) { return a.indexOf('--steps=') === 0; })[0];
        if (env) { steps = env.slice(8).split(' ').filter(function (s) { return s; }); runner.start(); }
    }
}
