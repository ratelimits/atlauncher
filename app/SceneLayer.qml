import QtQuick 2.12
import QtGraphicalEffects 1.12

/* One backdrop scene: the sharp art (decoded straight to 1920x1080) or a brand gradient, and its frost — the art
   shrunk to 192x108 on the GPU, blurred there, and drawn scaled up (the blur is a small pass whenever the art
   changes, nothing per frame; the picture is decoded only once). `sharp` and `frost` are textures for Glass. Art is assumed 16:9 (the bundled splashes and
   TMDB backdrops are), so the texture maps straight onto the screen. */
Item {
    id: layer
    width: 1920
    height: 1080

    property string key: ''
    property string src: ''
    property var gradient: null
    // 0..1: how much of the frost covers the sharp art (the grid, the sectioned shelf, Settings).
    property real frostLevel: 0
    // Hide the sharp art (Settings covers everything; only the frost texture is needed).
    property bool covered: false
    // Decoded size of the art (test: 3840x2160).
    property size artSize: Qt.size(1920, 1080)

    readonly property bool ready: gradient ? true : sharpImg.status === Image.Ready
    readonly property bool failed: !gradient && sharpImg.status === Image.Error
    readonly property variant sharp: gradient ? gradTex : sharpImg
    readonly property variant frost: gradient ? gradTex : frostTex

    // Sharp art.
    Image {
        id: sharpImg
        anchors.fill: parent
        source: layer.gradient ? '' : layer.src
        sourceSize: layer.artSize
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: !layer.gradient
    }

    // Gradient scenes: drawn small (a smooth gradient loses nothing) and scaled up, both as picture and as texture.
    Rectangle {
        id: gradSmall
        width: 192
        height: 108
        visible: !!layer.gradient
        gradient: Gradient {
            GradientStop { position: 0; color: layer.gradient ? layer.gradient[0] : '#000' }
            GradientStop { position: 0.78; color: layer.gradient ? layer.gradient[1] : '#000' }
        }
    }
    ShaderEffectSource { id: gradTex; sourceItem: gradSmall; hideSource: true; visible: false; smooth: true }

    // Frost: the art shrunk on the GPU and blurred small. Once the frost covers the art (or Settings covers both),
    // this also stops the sharp art being drawn on screen (hideSource), while it still renders into the texture.
    ShaderEffectSource {
        id: smallTex
        sourceItem: sharpImg
        textureSize: Qt.size(192, 108)
        hideSource: layer.covered || layer.frostLevel >= 1
        visible: false
        smooth: true
    }
    FastBlur {
        id: blurred
        width: 192
        height: 108
        source: smallTex
        radius: 40
        transparentBorder: false
        visible: !layer.gradient
    }
    ShaderEffectSource { id: frostTex; sourceItem: blurred; hideSource: true; visible: false; smooth: true }

    // The picture on screen: sharp art under its frost (or the gradient).
    ShaderEffect {
        anchors.fill: parent
        property variant tex: layer.frost
        visible: !!layer.gradient || layer.frostLevel > 0
        opacity: layer.gradient ? 1 : layer.frostLevel
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform lowp float qt_Opacity;
            uniform sampler2D tex;
            void main() { gl_FragColor = texture2D(tex, qt_TexCoord0) * qt_Opacity; }
        "
    }
}
