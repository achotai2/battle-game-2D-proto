shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, cull_disabled; 

group_uniforms Ink_Settings;
uniform vec3 ink_color : source_color = vec3(0.1, 0.1, 0.15); 
uniform float outline_threshold = 0.5; // Tweak this first!
uniform float line_thickness = 1.0; 
uniform float max_ink_distance : hint_range(0.0, 1000.0) = 300.0;
uniform float distance_fade_strength : hint_range(0.0, 3.0) = 1.0;

group_uniforms Hand_Drawn_Distortion;
uniform sampler2D noise_texture : repeat_enable, filter_linear; 
uniform float distortion_strength : hint_range(0.0, 0.01) = 0.002;
uniform float noise_scale = 3.0;

// BUILT-IN 3D TEXTURES
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Ink_Wash;
uniform float wash_distance_start = 100.0; // Only wash mountains far away
uniform int wash_steps : hint_range(1, 20) = 10; // How long the drip is
uniform float wash_stride = 3.0; // How far the drip travels (in pixels)
uniform float wash_falloff_curve : hint_range(0.1, 10.0) = 2.0; // Bends the fade gradient
uniform float wash_multiplier : hint_range(1.0, 10.0) = 2.5; // Punches up the dark ink at the edge

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
	// 1.1. Get the Camera's World Position
	// INV_VIEW_MATRIX[3].xyz automatically grabs the camera's X, Y, and Z location
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;

	// 1.2. Calculate the Parallax Offset
	// We multiply by a tiny number so the noise doesn't fly across the screen too fast.
	// Because you are looking North (down the Z axis), X moves left/right, and Z moves up/down.
	float parallax_speed = 0.005; // Tweak this until it matches the terrain movement!
	vec2 cam_offset = vec2(cam_pos.x, cam_pos.z) * parallax_speed;

	// 1.3. Keep the smooth SCREEN_UV logic, but add the camera offset
	vec2 noise_uv = (SCREEN_UV * noise_scale) + cam_offset;

	// 1.4. Sample the perfectly smooth noise
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
	// A 5-meter drop near the camera is a cliff. A 5-meter drop at 500m is just flat ground.
	// We scale the required threshold exponentially based on the pixel's depth.
	float distance_scaling = pow(max(pixel_depth, 1.0), distance_fade_strength);
	
	// Divide our detected edge by the distance scaler
	float normalized_edge = edge / distance_scaling;

	// Now check if the normalized edge beats your outline threshold
	float line_mask = step(outline_threshold, normalized_edge); 
	
	// Step returns 1.0 if pixel_depth is less than max_ink_distance, otherwise 0.0
	float distance_mask = step(pixel_depth, max_ink_distance);
	line_mask *= distance_mask;
	
	// --- 5. The Downward Ink Wash ---
	float wash_intensity = 0.0;
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	
	// Pre-sample the noise so the ink drip looks fibrous and messy, not perfect
	float wash_noise = texture(noise_texture, ((SCREEN_UV * 2.0) + cam_offset)).r;
	
	// Create a mask so the wash only happens to distant mountains
	float distant_wash_mask = smoothstep(wash_distance_start, wash_distance_start + 50.0, pixel_depth);

	// Only run the loop if we are in the distant wash zone (saves GPU power!)
	if (distant_wash_mask > 0.0 && pixel_depth < 1000.0) {
		
		// Look upwards pixel by pixel
		for(int i = 1; i <= wash_steps; i++) {
			
			// Move our sample point up the screen
			vec2 sample_uv = SCREEN_UV + vec2(0.0, -texel.y * float(i) * wash_stride);
			float sample_depth = get_linear_depth(sample_uv, INV_PROJECTION_MATRIX);
			
			// If the pixel above us is significantly further away, we hit a ridge!
			if (sample_depth - pixel_depth > 30.0) {
				
// 1. Calculate the standard linear fade (1.0 at edge, 0.0 at max distance)
				float linear_wash = 1.0 - (float(i) / float(wash_steps));
				
				// 2. Bend the straight line into a curve using pow()
				float curved_wash = pow(linear_wash, wash_falloff_curve);
				
				// 3. Multiply the intensity to make the edge pure dark ink
				// We clamp it so it doesn't accidentally exceed 1.0 and cause visual glitches
				wash_intensity = clamp(curved_wash * wash_noise * wash_multiplier, 0.0, 1.0);				

				// We found the ridge, stop looking up!
				break;
			}
		}
	}

	// Combine our hard edge lines with our soft ink wash
	float final_ink_mask = clamp(line_mask + (wash_intensity * distant_wash_mask), 0.0, 1.0);
	
	// 6. Output
	vec3 original_color = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(original_color, ink_color, final_ink_mask);
}