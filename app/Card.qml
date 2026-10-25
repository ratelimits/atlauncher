import QtQuick 2.12
import "."

// A show in the sectioned "Top Shows" shelf: 840x472 art, its name under it; focus lifts it 4px and scales 1.06.
Item {
    id: card
    width: 840
    height: 472
    property var item: ({})
    property bool focused: false
    property bool pressed: false
    z: focused ? 2 : 0

    function kick(dx) { kickAnim.dir = dx < 0 ? -1 : 1; kickAnim.restart(); }
    function land() { }
    function bump(direction) { bumpAnim.dx = direction === 'left' ? -8 : 8; bumpAnim.restart(); }

    transform: [
        Translate { id: bumpT },
        Translate { y: card.focused ? -4 : 0; Behavior on y { NumberAnimation { duration: 250 } } }
    ]
    scale: pressed ? 1.035 : focused ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.15, 1, 1] } }

    SequentialAnimation {
        id: bumpAnim
        property real dx: 0
        NumberAnimation { target: bumpT; property: 'x'; to: bumpAnim.dx; duration: 112; easing.type: Easing.OutCubic }
        NumberAnimation { target: bumpT; property: 'x'; to: 0; duration: 168; easing.type: Easing.OutCubic }
    }

    Shadow {
        shapeW: card.width
        shapeH: card.height
        radius: 34
        blur: 46
        dy: 26
        strength: 0.5
        opacity: card.focused ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    Rectangle { anchors.fill: parent; radius: 34; antialiasing: true; color: '#26262c'; visible: art.status !== Image.Ready }

    Item {
        anchors.fill: parent
        transform: Rotation {
            id: tilt
            origin.x: 420
            origin.y: 236
            axis: Qt.vector3d(0, 1, 0)
            angle: 0
        }
        SequentialAnimation {
            id: kickAnim
            property real dir: 1
            NumberAnimation { target: tilt; property: 'angle'; to: 5 * kickAnim.dir; duration: 88; easing.type: Easing.OutQuad }
            NumberAnimation { target: tilt; property: 'angle'; to: -1.2 * kickAnim.dir; duration: 198; easing.type: Easing.InOutQuad }
            NumberAnimation { target: tilt; property: 'angle'; to: 0; duration: 234; easing.type: Easing.InOutQuad }
        }
        RoundedImage {
            id: art
            anchors.fill: parent
            radius: 34
            source: card.item.card || ''
            lit: card.focused ? 1 : 0
            Behavior on lit { NumberAnimation { duration: 250 } }
        }
    }

    Text {
        y: 502
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: card.item.name || ''
        font.family: Style.font
        font.weight: Font.Medium
        font.pixelSize: 30
        color: card.focused ? 'white' : Qt.rgba(1, 1, 1, 0.45)
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
