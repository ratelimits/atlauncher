import QtQuick 2.12
import "."

/* An icon: its SF Symbol from the SF Pro font you installed (Style.symbol), else the bundled Lucide picture
   glyphs/<name>[-focus].png. `color` tints the symbol; the pictures carry their own colours. */
Item {
    id: glyph
    property string name: ''
    property bool focusVariant: false
    property color color: 'white'
    property real symbolScale: 0.78
    readonly property string character: Style.symbol(name)

    Text {
        anchors.centerIn: parent
        visible: glyph.character !== ''
        text: glyph.character
        color: glyph.color
        font.family: Style.font
        font.pixelSize: Math.round(Math.min(glyph.width, glyph.height) * glyph.symbolScale)
    }
    Image {
        anchors.fill: parent
        visible: glyph.character === '' && glyph.name !== ''
        source: glyph.name ? 'glyphs/' + glyph.name + (glyph.focusVariant ? '-focus' : '') + '.png' : ''
        sourceSize: Qt.size(Math.max(96, width * 2), Math.max(96, height * 2))
        smooth: true
        fillMode: Image.PreserveAspectFit
    }
}
