import QtQuick 2.12

/* An image with rounded corners and tvOS icon lighting, in one shader pass (no clip masks). Light comes from above,
   a little to the left: the rim catches it most along the top edge and down the left side, fading towards the right
   and gone at the bottom. At rest only a faint rim; focused (`lit` 0..1), a bright rim, a soft glow falling inward
   from the lit edges, and a gentle gloss across the top of the face. */
ShaderEffect {
    id: root
    property alias source: img.source
    property alias status: img.status
    property real radius: 28
    property real lit: 0
    property variant tex: img
    property size px: Qt.size(width, height)

    Image {
        id: img
        visible: false
        asynchronous: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(root.width * 2), Math.round(root.height * 2))
    }

    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform sampler2D tex;
        uniform highp vec2 px;
        uniform highp float radius;
        uniform lowp float lit;

        void main() {
            highp vec2 p = qt_TexCoord0 * px;
            highp vec2 c = px * 0.5;
            highp vec2 q = abs(p - c) - (c - vec2(radius));
            highp float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            highp vec2 sg = sign(p - c);
            highp vec2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q) * sg : (q.x > q.y ? vec2(sg.x, 0.0) : vec2(0.0, sg.y));
            lowp float a = clamp(0.5 - dist, 0.0, 1.0);
            highp float d = max(0.0, -dist);
            lowp vec4 col = texture2D(tex, qt_TexCoord0);

            // How much this part of the rim faces the light (above, slightly left).
            highp float face = max(dot(n, normalize(vec2(-0.45, -1.0))), 0.0);
            lowp float rim = (1.0 - smoothstep(0.6, 2.4, d)) * (0.05 + 0.65 * face) * mix(0.35, 1.0, lit);
            lowp float glow = exp(-d / 9.0) * 0.16 * face * lit;
            lowp float gloss = (1.0 - smoothstep(0.0, px.y * 0.55, p.y)) * 0.06 * lit;
            lowp float w = clamp(rim + glow + gloss, 0.0, 1.0);
            col.rgb += (col.a - col.rgb) * w;
            gl_FragColor = col * a * qt_Opacity;
        }
    "
}
