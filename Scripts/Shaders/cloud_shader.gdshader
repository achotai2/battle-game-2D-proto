shader_type spatial;
// Note: Changed to depth_draw_never so overlapping cloud layers don't block each other!
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D cloud_noise : repeat_enable;
uniform vec2 scroll_speed = vec2(0.01, 0.005);

uniform vec3 edge_color : source_color = vec3(1.0, 0.6, 0.3); 
uniform vec3 core_color : source_color = vec3(0.2, 0.2, 0.3); 

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5; 
uniform float edge_thickness : hint_range(0.01, 0.5) = 0.1; 

// --- PROXIMITY FADE UNIFORMS ---
// We pull in Godot's internal depth texture
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float proximity_fade_distance : hint_range(0.1, 50.0) = 15.0; // How soft the rock intersection is

void fragment() {
    // 1. Pan the clouds
    vec2 scrolled_uv = UV + (TIME * scroll_speed);
    float noise_val = texture(cloud_noise, scrolled_uv).r;

    // 2. Cut out the shape
    float cloud_mask = smoothstep(cloud_coverage, cloud_coverage + 0.05, noise_val);

    // 3. The Color Gradient
    float color_gradient = smoothstep(cloud_coverage, cloud_coverage + edge_thickness, noise_val);
    vec3 final_color = mix(edge_color, core_color, color_gradient);

    // --- 4. PROXIMITY FADE MATH ---
    // Read the raw depth of the solid mountains behind the mist
    float raw_depth = texture(depth_texture, SCREEN_UV).x;
    
    // Convert raw depth into meters (linear depth)
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float terrain_depth = -view.z;
    
    // The distance from the camera to the mist pixel being drawn
    float mist_depth = -VERTEX.z;
    
    // How close is the mist to the rock?
    float depth_difference = terrain_depth - mist_depth;
    
    // Create a soft gradient from 0.0 (touching) to 1.0 (far away)
    float proximity_fade = smoothstep(0.0, proximity_fade_distance, depth_difference);

    // 5. Output
	// We set Albedo to black so it doesn't react to 3D lighting
	ALBEDO = vec3(0.0);

	// We pump our custom color directly into the Emission channel so it glows flatly
	EMISSION = final_color;
    
    // Multiply the cloud mask by our new proximity fade so it vanishes at the edges!
    ALPHA = cloud_mask * proximity_fade;
}