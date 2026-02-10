shader_type canvas_item;
render_mode blend_mul;

uniform vec4 shadow_color: source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float cloud_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.1;

// SPEED: How fast time passes
uniform float speed_scale : hint_range(0.0, 5.0) = 1.0;

// DIRECTION: Vector for wind movement (normalized is best)
// Default is (1, 0.5) which moves them Right and slightly Down
uniform vec2 cloud_direction = vec2(1.0, 0.5);

global uniform float location_fade;

void fragment() {
    // 1. Calculate Movement Offset
    // We multiply direction by time and speed.
    vec2 movement = cloud_direction * TIME * speed_scale;

    // 2. Apply to Layers with Parallax
    // We divide movement by different amounts (100, 50, 25) to keep the depth effect.
    
    // Layer 1 (Slowest, biggest shapes)
    // We add 'movement / 100.0' to the UVs.
    vec3 fog_color_1 = texture(TEXTURE, UV / 2.0 + (movement / 100.0)).rgb;
    
    // Layer 2 (Medium speed, offset by 0.5 to avoid looking identical)
    vec3 fog_color_2 = texture(TEXTURE, UV / 2.0 + vec2(0.5) + (movement / 50.0)).rgb;
    
    // Layer 3 (Fastest detail)
    vec3 fog_color_3 = texture(TEXTURE, UV / 2.0 + vec2(0.25) + (movement / 25.0)).rgb;
    
    // Mix the noise layers (Same as before)
    // We use the red channel (.r) as the noise value
    float noise_1_2 = mix(fog_color_1.r, fog_color_2.r, 0.5);
    float noise_value = mix(fog_color_3.r, noise_1_2, 0.7);

    // 3. Calculate Mask & Color
    float shadow_mask = smoothstep(cloud_cutoff, cloud_cutoff + shadow_softness, noise_value);
    
    // Multiply Logic: White = Transparent, Grey = Shadow
    vec3 final_color = mix(vec3(1.0), shadow_color.rgb, shadow_mask);

    // 4. Output
    // Apply location fade (mix between pure white and shadow color)
    COLOR.rgb = mix(vec3(1.0), final_color, location_fade);
    COLOR.a = 1.0;
}