shader_type spatial;
// We don't need colors or blending, just solid opaque geometry for the shadow
render_mode depth_draw_opaque, cull_disabled;

uniform sampler2D cloud_noise : repeat_enable;
uniform vec2 scroll_speed = vec2(0.01, 0.005);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5; 

void fragment() {
    // 1. Pan the clouds at the exact same speed as the visual clouds
    vec2 scrolled_uv = UV + (TIME * scroll_speed);
    
    // 2. Sample the noise
    float noise_val = texture(cloud_noise, scrolled_uv).r;

    // 3. The Shadow Cutout
    // If the noise is below our coverage threshold, we delete the pixel so light passes through
    if (noise_val < cloud_coverage + 0.02) {
        discard;
    }

    // Output black (doesn't matter, it's invisible to the camera anyway!)
    ALBEDO = vec3(0.0);
}