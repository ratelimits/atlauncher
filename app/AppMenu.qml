import QtQuick 2.12
import "."

/* The app menu (hold OK on an app), as on tvOS 26: a frosted glass panel beside the icon, one row per action with
   its SF Symbol; the focused row is a white pill. Delete is system red. A confirmation reuses the panel (title
   above the rows). Home places it (x, y) and handles the keys; this only draws. */
Item {
    id: menu
    property var rows: []          // [{ id, label, glyph, red }]
    property int index: 0
    property string title: ''
    property bool shown: false
    property var backdrop: null

    // Concentric corners: the panel's radius is the focus pill's (rowH / 2) plus the gap around it (pad), so the pill
    // sits in the panel with an even margin, as on tvOS.
    readonly property int rowH: 74
    readonly property int pad: 16
    readonly property real radius: rowH / 2 + pad
    width: 540
    height: pad * 2 + (title ? titleText.height + 18 : 0) + rows.length * rowH

    signal activated(int row)
    signal hovered(int row)

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.1, 1, 1] } }

    Shadow { shapeW: menu.width; shapeH: menu.height; radius: menu.radius; blur: 50; dy: 24; strength: 0.4 }
    Glass {
        anchors.fill: parent
        screenX: menu.x
        screenY: menu.y
        sharpA: menu.backdrop ? menu.backdrop.back.sharp : null
        frostA: menu.backdrop ? menu.backdrop.back.frost : null
        sharpB: menu.backdrop ? menu.backdrop.front.sharp : null
        frostB: menu.backdrop ? menu.backdrop.front.frost : null
        mix: menu.backdrop ? menu.backdrop.mix : 1
        radius: menu.radius
        edge: 24
        liquid: 1
        frosted: 1
        dark: 0.35
    }

    Column {
        x: menu.pad
        y: menu.pad
        width: menu.width - 2 * menu.pad
        Text {
            id: titleText
            visible: !!menu.title
            width: parent.width
            height: visible ? implicitHeight + 18 : 0
            leftPadding: 22
            rightPadding: 22
            topPadding: 8
            wrapMode: Text.WordWrap
            text: menu.title
            font.family: Style.font; font.weight: Font.DemiBold; font.pixelSize: 28
            color: Qt.rgba(1, 1, 1, 0.85)
        }
        Repeater {
            model: menu.rows.length
            delegate: Item {
                id: rowItem
                readonly property var info: menu.rows[index] || ({})
                readonly property bool focused: index === menu.index
                width: parent.width
                height: menu.rowH
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    antialiasing: true
                    color: 'white'
                    opacity: rowItem.focused ? 1 : 0
                    scale: rowItem.focused ? 1 : 0.96
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                Row {
                    x: 26
                    height: parent.height
                    spacing: 18
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40
                        sourceSize: Qt.size(96, 96)
                        smooth: true
                        source: 'glyphs/menu-' + rowItem.info.glyph + (rowItem.focused ? '-focus' : '') + '.png'
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.info.label || ''
                        font.family: Style.font; font.weight: Font.Medium; font.pixelSize: 32
                        color: rowItem.info.red ? '#ff453a' : rowItem.focused ? '#1c1c1e' : 'white'
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: menu.hovered(index)
                    onClicked: menu.activated(index)
                }
            }
        }
    }
}
