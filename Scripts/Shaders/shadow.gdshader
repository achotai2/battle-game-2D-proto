shader_type canvas_item;
render_mode blend_mul; 

global uniform vec4 global_shadow_color;

void fragment() {
    // 1. Sample the Alpha ONLY
    float alpha = texture(TEXTURE, UV).a;
    
    // 2. Hard Cutoff (Optional but recommended for pixel art)
    // This removes semi-transparent fuzzy edges which can look like dirty rectangles.
    // If you want soft shadows, remove this line.
    if (alpha < 0.01) {
        discard; // Don't draw anything at all for empty space
    }

    // 3. The Math
    // We want the shadow color where alpha is 1.0.
    // We want PURE WHITE (vec3(1.0)) where alpha is 0.0 (Invisible in Multiply).
    vec3 final_rgb = mix(vec3(1.0), global_shadow_color.rgb, alpha);
    
    // 4. Force Alpha to 1.0
    // In Multiply mode, we don't want "transparency". We want "whiteness".
    // If we output alpha < 1.0, Godot tries to blend the sprite with the background
    // BEFORE multiplying, which causes the grey box artifact.
    COLOR = vec4(final_rgb, 1.0);
}