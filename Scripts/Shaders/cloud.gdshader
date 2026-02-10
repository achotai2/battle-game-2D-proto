shader_type canvas_item;
// 'blend_mul' means: White = Transparent, Dark = Shadow.
render_mode blend_mul;

// Set this to a LIGHT GREY in the Inspector (e.g., #cccccc).
// The darker the grey, the darker the shadow.
// Pure White (1.0) = No Shadow.
uniform vec4 shadow_color: source_color = vec4(0.8, 0.8, 0.8, 1.0);

uniform float cloud_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.1;

global uniform float location_fade;

void fragment() {
    // 1. Get Noise (Standard)
    vec3 fog_color_1 = texture(TEXTURE, vec2(UV.x / 2.0 + TIME / 100.0, UV.y / 4.0 - TIME / 100.0)).rgb;
    vec3 fog_color_2 = texture(TEXTURE, vec2(UV.x / 2.0 + 0.5 + TIME / 50.0, UV.y / 4.0 + 0.5 - TIME / 160.0)).rgb;
    vec3 fog_color_3 = texture(TEXTURE, vec2(UV.x / 2.0 + 0.25 + TIME / 25.0 , UV.y / 4.0 - 0.25 + TIME / 160.0)).rgb;
    float noise_value = mix(fog_color_3, mix(fog_color_1, fog_color_2, 0.5), 0.7).r;

    // 2. Calculate Mask
    float shadow_mask = smoothstep(cloud_cutoff, cloud_cutoff + shadow_softness, noise_value);

    // 3. Apply Logic (Multiply Mode)
    // We want the "Shadowy" parts to be our 'shadow_color' (Dark Grey).
    // We want the "Clear" parts to be White (Invisible in blend_mul).

    // Mix between White (No Shadow) and ShadowColor based on the mask
    vec3 final_color = mix(vec3(1.0), shadow_color.rgb, shadow_mask);

    // 4. Apply Fade
    // If location_fade is 0 (OFF), we force color to White (Invisible).
    // If location_fade is 1 (ON), we keep the final_color.
    COLOR.rgb = mix(vec3(1.0), final_color, location_fade);

    // Alpha doesn't matter much in blend_mul, but keep it 1.0 to be safe.
    COLOR.a = 1.0;
}