#version 300 es
// Migrado a GLSL ES 3.00 el 2026-09-18: Hyprland 0.56.2 exige #version 300 es.
// Cambios: varying -> in, texture2D -> texture, gl_FragColor -> out vec4 fragColor.

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    fragColor = vec4(1.0 - pixColor.r, 1.0 - pixColor.g, 1.0 - pixColor.b, pixColor.a);
}
