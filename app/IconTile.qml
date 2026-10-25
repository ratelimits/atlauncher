import QtQuick 2.12

/* A tile for an app without its own 5:3 art: the app's webOS icon (usually square, with its own background and lots
   of padding) drawn `iconScale` times the tile's height, centred, on a background taken from the icon's own edge
   pixels, so the logo sits on one continuous surface (falling back to `color` where the icon's edge is transparent).
   At 1.67 (Fill) a square icon covers the tile, which is closest to curated tile art. Rounded corners and the tvOS
   rim lighting are the same as RoundedImage's, all in one pass. */
ShaderEffect {
    id: root
    property alias source: img.source
    property alias status: img.status
    property color color: '#3a3c46'
    property real iconScale: 1.67
    property real radius: 28
    property real lit: 0
    property variant tex: img
    property size px: Qt.size(width, height)
    // Icon size on the tile, in px, keeping the icon's aspect.
    property size iconPx: img.implicitHeight > 0
        ? Qt.size(height * iconScale * img.implicitWidth / img.implicitHeight, height * iconScale)
        : Qt.size(height * iconScale, height * iconScale)

    Image {
        id: img
        visible: false
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize: Qt.size(512, 512)
    }

    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform sampler2D tex;
        uniform lowp vec4 color;
        uniform highp vec2 px;
        uniform highp vec2 iconPx;
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

            // Ground: the icon's own edge colour (average of its four edge midpoints), else the brand colour.
            lowp vec4 e = (texture2D(tex, vec2(0.02, 0.5)) + texture2D(tex, vec2(0.98, 0.5)) +
                           texture2D(tex, vec2(0.5, 0.02)) + texture2D(tex, vec2(0.5, 0.98))) * 0.25;
            lowp vec3 ground = e.a > 0.9 ? e.rgb / e.a : color.rgb;
            highp vec2 uv = (p - (c - iconPx * 0.5)) / iconPx;
            lowp vec4 icon = (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) ? texture2D(tex, uv) : vec4(0.0);
            lowp vec3 col = icon.rgb + ground * (1.0 - icon.a);

            highp float face = max(dot(n, normalize(vec2(-0.45, -1.0))), 0.0);
            lowp float rim = (1.0 - smoothstep(0.6, 2.4, d)) * (0.05 + 0.65 * face) * mix(0.35, 1.0, lit);
            lowp float glow = exp(-d / 9.0) * 0.16 * face * lit;
            lowp float gloss = (1.0 - smoothstep(0.0, px.y * 0.55, p.y)) * 0.06 * lit;
            col += (1.0 - col) * clamp(rim + glow + gloss, 0.0, 1.0);
            gl_FragColor = vec4(col, 1.0) * a * qt_Opacity;
        }
    "
}
