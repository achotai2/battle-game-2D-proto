shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled; 

group_uniforms Ink_Settings;
uniform vec3 ink_color : source_color = vec3(0.1, 0.1, 0.15); 
uniform float outline_threshold = 0.5; // Tweak this first!
uniform float line_thickness = 1.0; 

uniform float max_ink_distance : hint_range(0.0, 1000.0) = 300.0;

group_uniforms Hand_Drawn_Distortion;
uniform sampler2D noise_texture : repeat_enable, filter_linear; 
uniform float distortion_strength : hint_range(0.0, 0.01) = 0.002;
uniform float noise_scale = 3.0;

// BUILT-IN 3D TEXTURES
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

float get_linear_depth(vec2 uv, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	// -1.0 keeps the quad flat on the screen in Compatibility mode
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// 1. Hand-drawn UV distortion
	vec2 noise_uv = SCREEN_UV * noise_scale;
	vec2 distortion = (texture(noise_texture, noise_uv).rg - 0.5) * distortion_strength;
	vec2 messy_uv = SCREEN_UV + distortion;
	vec2 offset = (1.0 / VIEWPORT_SIZE) * line_thickness;
	
	vec2 uvs[9];
	uvs[0] = messy_uv + vec2(-offset.x, -offset.y);
	uvs[1] = messy_uv + vec2(0.0,       -offset.y);
	uvs[2] = messy_uv + vec2(offset.x,  -offset.y);
	uvs[3] = messy_uv + vec2(-offset.x, 0.0);
	uvs[4] = messy_uv;
	uvs[5] = messy_uv + vec2(offset.x,  0.0);
	uvs[6] = messy_uv + vec2(-offset.x, offset.y);
	uvs[7] = messy_uv + vec2(0.0,       offset.y);
	uvs[8] = messy_uv + vec2(offset.x,  offset.y);

	// 2. Sobel Math
	float depth_diff_x = 0.0;
	float depth_diff_y = 0.0;
	float kernel_x[9] = {-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0};
	float kernel_y[9] = {-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0};

	for (int i = 0; i < 9; i++) {
		float d = min(get_linear_depth(uvs[i], INV_PROJECTION_MATRIX), 1000.0);
		depth_diff_x += d * kernel_x[i];
		depth_diff_y += d * kernel_y[i];
	}

	float edge = sqrt(depth_diff_x * depth_diff_x + depth_diff_y * depth_diff_y);
	
	// 3. Artifact Cleaning & Depth Capture
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	float pixel_depth = get_linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	
	if (raw_depth >= 1.0 || raw_depth < 0.0001) {
		edge = 0.0;
	}

	// 4. Output with HARD Distance Cutoff
	// Step returns 1.0 if pixel_depth is less than max_ink_distance, otherwise 0.0
	float distance_mask = step(pixel_depth, max_ink_distance);
	
	// Apply the line mask and then multiply by our distance mask to turn it off
	float line_mask = step(outline_threshold, edge) * distance_mask; 
	
	vec3 original_color = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(original_color, ink_color, line_mask);
}