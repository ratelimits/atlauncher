import QtQuick 2.12

/* The Top Shelf backdrop: two SceneLayers. show(scene) loads the scene into the hidden one and, once its art is
   decoded, dissolves it in over the current one (550 ms) — so a scene is never shown half-loaded. Glass reads
   the same two layers (back/front textures and `mix`) so the Dock always matches what is behind it. */
Item {
    id: root
    width: 1920
    height: 1080

    property real frostLevel: 0
    property bool covered: false
    property int dissolveMs: 550
    property size artSize: Qt.size(1920, 1080)

    property int frontIndex: 0
    readonly property var front: frontIndex === 0 ? l0 : l1
    readonly property var back: frontIndex === 0 ? l1 : l0
    readonly property real mix: front.opacity
    property var shownScene: null
    property var pending: null

    signal shown(var scene)

    function show(scene) {
        if (shownScene && shownScene.key === scene.key && !pending) return;
        if (pending && pending.key === scene.key) return;
        if (fade.running) fade.complete();
        pending = scene;
        var target = back;
        target.visible = true;
        target.opacity = 0;
        target.z = 0;
        target.key = scene.key;
        target.gradient = scene.gradient || null;
        target.src = scene.src || '';
        check.restart();
    }

    // Poll the loading layer briefly (status changes arrive asynchronously).
    Timer {
        id: check
        interval: 16
        repeat: true
        onTriggered: {
            var target = root.back;
            if (!root.pending || target.key !== root.pending.key) { stop(); return; }
            if (target.failed) { stop(); root.pending = null; return; }
            if (!target.ready) return;
            stop();
            var scene = root.pending;
            root.pending = null;
            target.z = 1;
            root.front.z = 0;
            root.frontIndex = target === l0 ? 0 : 1;
            root.shownScene = scene;
            root.shown(scene);
            fade.target = target;
            fade.start();
        }
    }

    NumberAnimation {
        id: fade
        property: 'opacity'
        from: 0
        to: 1
        duration: root.dissolveMs
        onStopped: root.back.visible = false   // fully covered: stop drawing it
    }

    SceneLayer { id: l0; frostLevel: root.frostLevel; covered: root.covered; artSize: root.artSize }
    SceneLayer { id: l1; frostLevel: root.frostLevel; covered: root.covered; artSize: root.artSize; opacity: 0; visible: false }
}
