import QtQuick 2.12

/* A soft drop shadow for a rounded rectangle (CSS box-shadow 0 dy blur rgba(0,0,0,strength)), one shader pass.
   Place it over the shape's own rectangle; it draws `blur` px beyond it on every side. */
ShaderEffect {
    id: root
    property real radius: 28
    property real blur: 40
    property real dy: 22
    property real strength: 0.5
    // The shape's size; the item itself is larger by the blur.
    property real shapeW: 250
    property real shapeH: 150

    x: -blur
    y: -blur + dy
    width: shapeW + 2 * blur
    height: shapeH + 2 * blur

    property size px: Qt.size(width, height)
    property size shape: Qt.size(shapeW, shapeH)

    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform highp vec2 px;
        uniform highp vec2 shape;
        uniform highp float radius;
        uniform highp float blur;
        uniform lowp float strength;
        void main() {
            highp vec2 p = qt_TexCoord0 * px - px * 0.5;
            highp vec2 q = abs(p) - (shape * 0.5 - vec2(radius));
            highp float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            // CSS blur is a Gaussian with sigma = blur / 2: approximated by a smoothstep over +-blur/2... widened.
            lowp float a = 1.0 - smoothstep(-blur * 0.5, blur * 0.75, d);
            gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0) * a * a * strength * qt_Opacity;
        }
    "
}
