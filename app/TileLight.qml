import QtQuick 2.12

// RoundedImage's tvOS lighting on its own (premultiplied white), for tiles drawn some other way (an app's own icon
// on its brand colour). Same light: above, slightly left; `lit` 0..1 is focus.
ShaderEffect {
    property real radius: 28
    property real lit: 0
    property size px: Qt.size(width, height)
    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
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
            highp float face = max(dot(n, normalize(vec2(-0.45, -1.0))), 0.0);
            lowp float rim = (1.0 - smoothstep(0.6, 2.4, d)) * (0.05 + 0.65 * face) * mix(0.35, 1.0, lit);
            lowp float glow = exp(-d / 9.0) * 0.16 * face * lit;
            lowp float gloss = (1.0 - smoothstep(0.0, px.y * 0.55, p.y)) * 0.06 * lit;
            gl_FragColor = vec4(clamp(rim + glow + gloss, 0.0, 1.0)) * a * qt_Opacity;
        }
    "
}
