#version 300 es
// Renderizado el 2026-09-30 desde /usr/share/hyprshade/shaders/blue-light-filter.glsl.mustache
// Motivo: el shader del SISTEMA con este mismo nombre es una plantilla mustache, y
// hyprshade no puede renderizarla porque `chevron` sólo está instalado para Python
// 3.13 mientras hyprshade corre en 3.14. Fallaba con "No module named 'chevron'".
// Se congelan aquí los valores por defecto de la plantilla: 2600 K, fuerza 1.0.
// OJO: `#version` va en la PRIMERA línea, antes de cualquier comentario. En GLSL ES
// un comentario previo invalida el shader ("#version: statement must appear first
// in es-profile shader"). La plantilla original no cumple eso y no compila.
/*
 * Blue Light Filter
 *
 * Use warmer colors to make the display easier on your eyes.
 *
 * Source: https://github.com/hyprwm/Hyprland/issues/1140#issuecomment-1335128437
 */

precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

/**
 * Color temperature in Kelvin.
 * https://en.wikipedia.org/wiki/Color_temperature
 *
 * @min 1000.0
 * @max 40000.0
 */
const float Temperature = float(2600.0);

/**
 * Strength of filter.
 *
 * @min 0.0
 * @max 1.0
 */
const float Strength = float(1.0);

#define WithQuickAndDirtyLuminancePreservation
const float LuminancePreservationFactor = 1.0;

// function from https://www.shadertoy.com/view/4sc3D7
// valid from 1000 to 40000 K (and additionally 0 for pure full white)
vec3 colorTemperatureToRGB(const in float temperature) {
    // values from: http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693
    mat3 m = (temperature <= 6500.0)
        ? mat3(vec3(0.0, -2902.1955373783176, -8257.7997278925690),
               vec3(0.0, 1669.5803561666639, 2575.2827530017594),
               vec3(1.0, 1.3302673723350029, 1.8993753891711275))
        : mat3(vec3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
               vec3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
               vec3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275));

    return mix(
        clamp(m[0] / (vec3(clamp(temperature, 1000.0, 40000.0)) + m[1]) + m[2], 0.0, 1.0),
        vec3(1.0),
        smoothstep(1000.0, 0.0, temperature)
    );
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

#ifdef WithQuickAndDirtyLuminancePreservation
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color *= mix(1.0, lum / max(lum, 1e-5), LuminancePreservationFactor);
#endif

    color = mix(color, color * colorTemperatureToRGB(Temperature), Strength);

    fragColor = vec4(color, pixColor.a);
}

// vim: ft=glsl
