import QtQuick 2.9

/* tvOS 27 focus glow: a soft halo around a rounded rectangle (the same falloff as Shadow, so it is centred by
   construction), coloured with the icon's average colour. `source` is a tiny texture of the icon (4x4); the shader
   averages its 16 texels. Place it over the shape's own rectangle; it draws `blur` px beyond it on every side. */
ShaderEffect {
    id: root
    property variant source
    property real radius: 28
    property real blur: 44
    property real strength: 0.3
    property real shapeW: 250
    property real shapeH: 150

    x: -blur
    y: -blur
    width: shapeW + 2 * blur
    height: shapeH + 2 * blur

    property size px: Qt.size(width, height)
    property size shape: Qt.size(shapeW, shapeH)

    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform sampler2D source;
        uniform highp vec2 px;
        uniform highp vec2 shape;
        uniform highp float radius;
        uniform highp float blur;
        uniform lowp float strength;
        void main() {
            lowp vec4 c = vec4(0.0);
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 4; j++)
                    c += texture2D(source, vec2((float(i) + 0.5) / 4.0, (float(j) + 0.5) / 4.0));
            c /= 16.0;
            // Unpremultiply, then lift dark icons a little so the glow stays a colour, not a shadow.
            lowp vec3 col = c.a > 0.01 ? c.rgb / c.a : vec3(0.0);
            highp vec2 p = qt_TexCoord0 * px - px * 0.5;
            highp vec2 q = abs(p) - (shape * 0.5 - vec2(radius));
            highp float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            lowp float a = 1.0 - smoothstep(-blur * 0.3, blur, d);
            gl_FragColor = vec4(col, 1.0) * a * a * strength * qt_Opacity;
        }
    "
}
