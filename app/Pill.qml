import QtQuick 2.12
import "."

// A tvOS button: translucent at rest; focused, white with dark text, scaled 1.08 on a soft shadow.
Item {
    id: pill
    property string label: ''
    property bool playIcon: false
    property bool focused: false
    property bool pressed: false
    width: row.width + 92
    height: 74

    function bump(direction) { bumpAnim.dx = direction === 'left' ? -6 : 6; bumpAnim.restart(); }

    transform: Translate { id: bumpT }
    scale: pressed ? 1.035 : focused ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.15, 1, 1] } }
    SequentialAnimation {
        id: bumpAnim
        property real dx: 0
        NumberAnimation { target: bumpT; property: 'x'; to: bumpAnim.dx; duration: 112; easing.type: Easing.OutCubic }
        NumberAnimation { target: bumpT; property: 'x'; to: 0; duration: 168; easing.type: Easing.OutCubic }
    }

    Shadow {
        shapeW: pill.width; shapeH: pill.height; radius: 37; blur: 32; dy: 16; strength: 0.35
        opacity: pill.focused ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: pill.focused ? 'white' : Qt.rgba(1, 1, 1, 0.22)
        Behavior on color { ColorAnimation { duration: 180 } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Canvas {
            visible: pill.playIcon
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            property color fill: label.color
            onFillChanged: requestPaint()
            onPaint: {
                var ctx = getContext('2d');
                ctx.reset();
                ctx.fillStyle = fill;
                ctx.beginPath();
                ctx.moveTo(7, 4.6); ctx.lineTo(7, 19.4); ctx.lineTo(20.2, 12); ctx.closePath();
                ctx.fill();
            }
        }
        Text {
            id: label
            text: pill.label
            font.family: Style.font
            font.weight: Font.DemiBold
            font.pixelSize: 29
            color: pill.focused ? 'black' : 'white'
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
}
