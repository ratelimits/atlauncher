import QtQuick 2.12
import "."

// A show's title: its TMDB logo (fitted, bottom-left), or its name in large type until/unless there is one.
Item {
    id: mark
    property var scene: null
    property real maxW: 620
    property real maxH: 220
    property bool twoLines: false
    readonly property string logo: scene && scene.logo ? scene.logo : ''

    Image {
        id: img
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        // Decoded at the box's width (TMDB originals can be 3000+ px); fitted into maxW x maxH, kept at its aspect.
        sourceSize.width: mark.maxW
        readonly property real k: implicitWidth > 0 ? Math.min(mark.maxW / implicitWidth, mark.maxH / implicitHeight, 1) : 0
        width: implicitWidth * k
        height: implicitHeight * k
        source: mark.logo
        asynchronous: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
    }
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: mark.maxW
        visible: img.status !== Image.Ready && !!(mark.scene && mark.scene.item)
        text: mark.scene && mark.scene.item ? mark.scene.item.name : ''
        wrapMode: Text.WordWrap
        maximumLineCount: mark.twoLines ? 2 : 1
        elide: Text.ElideRight
        font.family: Style.font; font.weight: Font.Bold; font.pixelSize: 76
        lineHeight: 88; lineHeightMode: Text.FixedHeight
        color: 'white'
    }
}
