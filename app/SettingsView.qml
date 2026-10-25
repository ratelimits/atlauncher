import QtQuick 2.12
import "."

/* Settings (tvOS layout, as on the Chromecast and the web version): the focused row's picture and note on the left,
   rows on the right. Drawn over the current scene's frost, dimmed. The page content comes from Home (page). */
Item {
    id: view
    width: 1920
    height: 1080

    property variant frost
    // { title, rows: [{ label, value, page, glyph, image, color, note }] }
    property var page: ({ title: '', rows: [] })
    property int index: 0
    readonly property var row: page.rows[index] || ({})
    readonly property int pitch: 84
    readonly property int visibleRows: 10

    property bool pointerEnabled: true
    // Magic Remote: hovering a row focuses it, clicking it activates it.
    signal hovered(int row)
    signal clicked(int row)

    function bump(direction) { var r = rows.itemAt(index); if (r) r.bump(direction); }
    function pressRow() { var r = rows.itemAt(index); if (r) r.pressAnim(); }

    ShaderEffect {
        anchors.fill: parent
        property variant tex: view.frost
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform lowp float qt_Opacity;
            uniform sampler2D tex;
            void main() { gl_FragColor = vec4(texture2D(tex, qt_TexCoord0).rgb * 0.62, 1.0) * qt_Opacity; }
        "
    }

    // ---- Left: the focused row's picture and note ----
    Item {
        x: 190; y: 210; width: 480; height: 480
        Shadow { shapeW: 480; shapeH: 480; radius: 112; blur: 50; dy: 24; strength: 0.25; visible: !view.row.image }
        Rectangle {
            anchors.fill: parent
            visible: !view.row.image
            radius: 112
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.36) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.18) }
            }
            Glyph {
                anchors.centerIn: parent
                width: 300; height: 300
                name: view.row.glyph || ''
                color: '#2c2c30'
            }
        }
        // An app row: the app's own tile at its 5:3 shape.
        Item {
            visible: !!view.row.image
            y: 96; width: 480; height: 288
            Rectangle { anchors.fill: parent; radius: 56; antialiasing: true; color: view.row.color || 'transparent' }
            RoundedImage { anchors.fill: parent; radius: 56; source: view.row.image || ''; visible: !view.row.generic }
            Image {
                visible: !!view.row.generic
                anchors.centerIn: parent
                width: 288; height: 207
                fillMode: Image.PreserveAspectFit
                source: view.row.generic ? view.row.image : ''
            }
        }
    }
    Text {
        x: 200; y: 726; width: 460
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: view.row.note || ''
        font.family: Style.font
        font.weight: Font.Medium
        font.pixelSize: 24
        lineHeight: 33
        lineHeightMode: Text.FixedHeight
        color: Qt.rgba(1, 1, 1, 0.6)
    }

    // ---- Right: title and rows ----
    Text {
        x: 860; y: 54
        text: view.page.title
        font.family: Style.font
        font.weight: Font.Bold
        font.pixelSize: 56
        color: Qt.rgba(1, 1, 1, 0.72)
    }
    Item {
        x: 846; y: 168; width: 948; height: 860
        clip: true
        Item {
            id: track
            y: 12 - Math.max(0, Math.min(view.index - view.visibleRows + 3, view.page.rows.length - view.visibleRows)) * view.pitch
            width: parent.width
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
            Repeater {
                id: rows
                model: view.page.rows.length
                delegate: Item {
                    id: rowItem
                    readonly property var info: view.page.rows[index] || ({})
                    readonly property bool focused: index === view.index
                    x: 14; y: index * view.pitch; width: 920; height: 70
                    z: focused ? 1 : 0
                    function bump(direction) { bumpAnim.dx = direction === 'right' ? 6 : 0; bumpAnim.dy = direction === 'up' ? -6 : direction === 'down' ? 6 : 0; bumpAnim.restart(); }
                    function pressAnim() { pressSeq.restart(); }
                    transform: Translate { id: bumpT }
                    scale: focused ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.15, 1, 1] } }
                    SequentialAnimation {
                        id: bumpAnim
                        property real dx: 0
                        property real dy: 0
                        ParallelAnimation {
                            NumberAnimation { target: bumpT; property: 'x'; to: bumpAnim.dx; duration: 112 }
                            NumberAnimation { target: bumpT; property: 'y'; to: bumpAnim.dy; duration: 112 }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: bumpT; property: 'x'; to: 0; duration: 168 }
                            NumberAnimation { target: bumpT; property: 'y'; to: 0; duration: 168 }
                        }
                    }
                    SequentialAnimation {
                        id: pressSeq
                        NumberAnimation { target: rowItem; property: 'scale'; to: 0.995; duration: 100 }
                        NumberAnimation { target: rowItem; property: 'scale'; to: rowItem.focused ? 1.03 : 1; duration: 100 }
                    }
                    Shadow { shapeW: 920; shapeH: 70; radius: 35; blur: 30; dy: 14; strength: 0.3; visible: rowItem.focused }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: view.pointerEnabled
                        property point last: Qt.point(-1, -1)
                        onPositionChanged: {
                            var g = mapToItem(null, mouse.x, mouse.y);
                            if (g.x === last.x && g.y === last.y) return;
                            last = g;
                            view.hovered(index);
                        }
                        onClicked: view.clicked(index)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 35
                        antialiasing: true
                        color: rowItem.focused ? 'white' : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    Row {
                        x: 34; width: parent.width - 68; height: parent.height
                        spacing: 0
                        Text {
                            width: parent.width - valueText.width - chev.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowItem.info.label || ''
                            elide: Text.ElideRight
                            font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 32
                            color: rowItem.focused ? 'black' : 'white'
                        }
                        Text {
                            id: valueText
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 24
                            text: rowItem.info.value || ''
                            visible: !!rowItem.info.value
                            width: visible ? implicitWidth : 0
                            font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 32
                            color: rowItem.focused ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.58)
                        }
                        Canvas {
                            id: chev
                            visible: !!rowItem.info.page
                            width: visible ? 35 : 0
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            property color stroke: rowItem.focused ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.58)
                            onStrokeChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext('2d');
                                ctx.reset();
                                ctx.strokeStyle = stroke;
                                ctx.lineWidth = 2.6;
                                ctx.lineCap = 'round';
                                ctx.lineJoin = 'round';
                                ctx.beginPath();
                                ctx.moveTo(22 + 2.5 * 13 / 12, 2.5 * 22 / 20);
                                ctx.lineTo(22 + 9.5 * 13 / 12, 11);
                                ctx.lineTo(22 + 2.5 * 13 / 12, 19.5 * 22 / 20);
                                ctx.stroke();
                            }
                        }
                    }
                }
            }
        }
    }
}
