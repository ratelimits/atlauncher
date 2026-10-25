import QtQuick 2.12
import "."

/* An app icon: depth, never outlines. Focus lifts and scales it 1.2 with a spring, tilts it toward the move (kick),
   and lights its rim from above as tvOS does (RoundedImage); a bump nudges it when there is nowhere to go; in edit mode the others
   jiggle. Curated apps use icons/<id>.png; others their own webOS icon on their brand colour. */
Item {
    id: tile
    width: 250
    height: 150

    property var app: ({})
    property bool focused: false
    property bool inGrid: false
    property bool pressed: false
    property bool editing: false
    // Size of an app's own icon on its tile, in tile heights (Settings > Appearance > Icon Size).
    property real iconScale: 1.67
    property bool showLabel: inGrid && focused

    readonly property real lift: inGrid ? -4 : 0
    // A built-in tile drawn with an SF Symbol (Settings' gear) when SF Pro is installed, instead of its picture.
    readonly property bool symbolTile: !!app.glyph && Style.symbol(app.glyph) !== ''
    z: focused ? 2 : 0

    function kick(dx, dy) {
        // The web version's kick-l/r (rotateY -/+7deg) and kick-u/d (rotateX +/-7deg).
        tilt.axis = Qt.vector3d(dx !== 0 ? 0 : 1, dx !== 0 ? 1 : 0, 0);
        kickAnim.dir = dx < 0 ? -1 : dx > 0 ? 1 : dy < 0 ? 1 : -1;
        kickAnim.restart();
    }
    function land() { }
    function bump(direction) {
        bumpAnim.dx = direction === 'left' ? -8 : direction === 'right' ? 8 : 0;
        bumpAnim.dy = direction === 'up' ? -8 : direction === 'down' ? 8 : 0;
        bumpAnim.restart();
    }

    // Focus: scale + lift (around the centre); the bump moves it on top of that.
    transform: [
        Translate { id: bumpT },
        Translate { y: tile.focused ? tile.lift : 0; Behavior on y { NumberAnimation { duration: 250 } } }
    ]
    scale: pressed ? 1.09 : focused ? 1.2 : 1
    Behavior on scale {
        NumberAnimation { duration: tile.pressed ? 100 : 250; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.15, 1, 1] }
    }

    SequentialAnimation {
        id: bumpAnim
        property real dx: 0
        property real dy: 0
        ParallelAnimation {
            NumberAnimation { target: bumpT; property: 'x'; to: bumpAnim.dx; duration: 112; easing.type: Easing.OutCubic }
            NumberAnimation { target: bumpT; property: 'y'; to: bumpAnim.dy; duration: 112; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: bumpT; property: 'x'; to: 0; duration: 168; easing.type: Easing.OutCubic }
            NumberAnimation { target: bumpT; property: 'y'; to: 0; duration: 168; easing.type: Easing.OutCubic }
        }
    }

    // Edit mode: the others jiggle, each out of step.
    property real jiggle: 0
    rotation: jiggle
    SequentialAnimation on jiggle {
        running: tile.editing && !tile.focused
        loops: Animation.Infinite
        PauseAnimation { duration: Math.random() * 260 }
        SequentialAnimation {
            loops: Animation.Infinite
            NumberAnimation { from: -1.3; to: 1.3; duration: 260; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.3; to: -1.3; duration: 260; easing.type: Easing.InOutQuad }
        }
        onRunningChanged: if (!running) tile.jiggle = 0
    }

    Shadow {
        shapeW: tile.width
        shapeH: tile.height
        radius: 28
        blur: 40
        dy: 22
        strength: 0.5
        opacity: tile.focused ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    Item {
        id: art
        anchors.fill: parent
        transform: Rotation {
            id: tilt
            origin.x: art.width / 2
            origin.y: art.height / 2
            axis: Qt.vector3d(0, 1, 0)
            angle: 0
        }
        SequentialAnimation {
            id: kickAnim
            property real dir: 1
            NumberAnimation { target: tilt; property: 'angle'; to: 7 * kickAnim.dir; duration: 88; easing.type: Easing.OutQuad }
            NumberAnimation { target: tilt; property: 'angle'; to: -1.6 * kickAnim.dir; duration: 198; easing.type: Easing.InOutQuad }
            NumberAnimation { target: tilt; property: 'angle'; to: 0; duration: 234; easing.type: Easing.InOutQuad }
        }

        // Curated tile art.
        RoundedImage {
            id: curated
            anchors.fill: parent
            visible: !!tile.app.tile && !tile.symbolTile
            source: tile.app.tile || ''
            radius: 28
            lit: tile.focused ? 1 : 0
            Behavior on lit { NumberAnimation { duration: 250 } }
        }
        Rectangle {
            anchors.fill: parent
            visible: tile.symbolTile
            radius: 28
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0; color: '#8e8e93' }
                GradientStop { position: 1; color: '#3a3a3e' }
            }
            Glyph { anchors.centerIn: parent; width: 84; height: 84; name: tile.app.glyph || ''; color: 'white' }
            TileLight {
                anchors.fill: parent
                radius: 28
                lit: tile.focused ? 1 : 0
                Behavior on lit { NumberAnimation { duration: 250 } }
            }
        }
        // The app's own icon, scaled up on its own edge colour (IconTile; size from Settings > Appearance).
        IconTile {
            anchors.fill: parent
            visible: !tile.app.tile && !tile.app.gap && !!tile.app.icon
            source: tile.app.icon || ''
            color: tile.app.color || '#3a3c46'
            iconScale: tile.iconScale
            radius: 28
            lit: tile.focused ? 1 : 0
            Behavior on lit { NumberAnimation { duration: 250 } }
        }
        // No icon (some LG system apps, or the desktop preview): its name on its colour.
        Rectangle {
            anchors.fill: parent
            visible: !tile.app.tile && !tile.app.gap && !tile.app.icon
            radius: 28
            antialiasing: true
            color: tile.app.color || '#3a3c46'
            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: tile.app.name || ''
                font.family: Style.font; font.weight: Font.DemiBold; font.pixelSize: 30
                color: 'white'
            }
            TileLight {
                anchors.fill: parent
                radius: 28
                lit: tile.focused ? 1 : 0
                Behavior on lit { NumberAnimation { duration: 250 } }
            }
        }
    }

    // Name: only under the focused icon, only in rows below the Dock (as on tvOS). Scaled with the tile.
    Text {
        x: -60
        width: tile.width + 120
        y: 169
        horizontalAlignment: Text.AlignHCenter
        text: tile.app.name || ''
        font.family: Style.font
        font.weight: Font.Medium
        font.pixelSize: 23
        color: 'white'
        elide: Text.ElideRight
        opacity: tile.showLabel ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}
