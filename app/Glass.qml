import QtQuick 2.12

/* Liquid Glass, as one fragment shader over the two backdrop scenes (back + front, crossfading by `mix`): the slab
   magnifies the sharp art a little (mag); within `band` px of its rounded rim the picture bends further inward,
   s(d) = bend (1 - d/band)^2, so lines bow where they cross the edge; the body fades to the frost over `edge` px;
   the art's own colour tints it; light from the top left catches the rim (a sharp highlight, a weaker reflection
   at the bottom right), with light and shade fading inward from the rim across the bevel.
   frosted = 1: the body and rim are all frost, as the backdrop behind is (the grid, the sectioned shelf); in
   between while that frost fades in. liquid = 0: a plain clear edge
   magnified 3.5% with a hairline glint, as with Liquid Glass off in Settings. All per pixel, every frame. */
ShaderEffect {
    id: glass
    // Screen position of this glass (the art inside lines up with the backdrop behind it).
    property real screenX: x
    property real screenY: y
    property variant sharpA
    property variant frostA
    property variant sharpB
    property variant frostB
    property real mix: 0
    property real radius: 66
    property real edge: 36
    property real liquid: 1
    property real frosted: 0
    property real dark: 0
    property real band: 40
    property real bend: 19
    property real mag: 1.018

    property size px: Qt.size(width, height)
    property point origin: Qt.point(screenX, screenY)

    blending: true
    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform sampler2D sharpA;
        uniform sampler2D frostA;
        uniform sampler2D sharpB;
        uniform sampler2D frostB;
        uniform lowp float mix;
        uniform highp vec2 px;
        uniform highp vec2 origin;
        uniform highp float radius;
        uniform highp float edge;
        uniform lowp float liquid;
        uniform lowp float frosted;
        uniform lowp float dark;
        uniform highp float band;
        uniform highp float bend;
        uniform highp float mag;

        const highp vec2 SCREEN = vec2(1920.0, 1080.0);

        lowp vec3 sharpAt(highp vec2 s) {
            highp vec2 uv = clamp(s / SCREEN, 0.0, 1.0);
            return mix(texture2D(sharpA, uv).rgb, texture2D(sharpB, uv).rgb, mix);
        }
        lowp vec3 frostAt(highp vec2 s) {
            highp vec2 uv = clamp(s / SCREEN, 0.0, 1.0);
            return mix(texture2D(frostA, uv).rgb, texture2D(frostB, uv).rgb, mix);
        }

        void main() {
            highp vec2 p = qt_TexCoord0 * px;
            highp vec2 c = px * 0.5;
            // Rounded-rectangle distance: negative inside; n = outward normal.
            highp vec2 q = abs(p - c) - (c - vec2(radius));
            highp float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            highp vec2 sg = sign(p - c);
            highp vec2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q) * sg : (q.x > q.y ? vec2(sg.x, 0.0) : vec2(0.0, sg.y));
            lowp float alpha = clamp(0.5 - dist, 0.0, 1.0);
            if (alpha <= 0.0) { gl_FragColor = vec4(0.0); return; }
            highp float d = max(0.0, -dist);              // depth inside the rim, px

            highp vec2 s = origin + p;                     // screen point under this pixel
            highp vec2 center = origin + c;
            lowp vec3 col;
            if (liquid > 0.5) {
                highp vec2 m = center + (s - center) / mag;
                highp float t = max(0.0, 1.0 - d / band);
                col = sharpAt(m - n * bend * t * t);
            } else {
                col = sharpAt(center + (s - center) / 1.035);
            }
            lowp vec3 fr = frostAt(s);
            lowp float body = mix(0.55 * smoothstep(0.0, edge, d), 1.0, frosted);
            col = mix(col, fr, body);
            // The art's own colour, from the frost at the glass centre (the web version's average-colour tint).
            col = mix(col, frostAt(center), 0.14);
            col = mix(col, vec3(0.0), dark);

            highp vec2 light = normalize(vec2(-1.0, -1.0));
            highp float lit = max(dot(n, light), 0.0), far = max(dot(n, -light), 0.0);
            if (liquid > 0.5) {
                lowp float rim = 1.0 - smoothstep(0.5, 2.5, d);
                col += vec3(rim * (0.10 + 0.80 * lit * lit + 0.42 * far * far));
                // Bevel light and shade fall off smoothly from the rim inward: no ring inside the edge (a ring a few
                // px in read as a second, smaller Dock).
                col += vec3(exp(-d / 10.0) * (0.02 + 0.14 * lit));
                col *= 1.0 - exp(-d / 8.0) * 0.14 * far;
            } else {
                col += vec3(0.05 * (1.0 - smoothstep(0.0, px.y * 0.4, p.y)));
                lowp float hair = 1.0 - smoothstep(0.75, 1.75, d);
                col += vec3(hair * mix(0.04, 0.34, lit));
            }
            gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * alpha * qt_Opacity;
        }
    "
}
