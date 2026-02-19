shader_type spatial;
render_mode depth_draw_opaque;

// Shanshui Shader - stylized terrain shader
// Based on simple4_lite.gdshader

// This is a shader with less textures, in case the main one doesn't run on your GPU.
// It's mostly a big copy/paste, because Godot doesn't support #include or #ifdef...

// TODO Figure out why sampling colormap or splatmap in vertex shader leads to artifacts.
// At extremely shallow angles (such as horizon), some pixels start to flash.
// It appears to be caused by interpolation between the vertex and fragment shaders, leading to
// color values going largely outside of 0..1.
// See https://github.com/Zylann/godot_heightmap_plugin/issues/469
//#define COLORMAP_PER_VERTEX
//#define SPLATMAP_PER_VERTEX

#include "res://addons/zylann.hterrain/shaders/include/heightmap.gdshaderinc"

uniform sampler2D u_terrain_heightmap;
uniform sampler2D u_terrain_normalmap;
// I had to remove `hint_albedo` from colormap in Godot 3 because it makes sRGB conversion kick in,
// which snowballs to black when doing GPU painting on that texture...
uniform sampler2D u_terrain_colormap;// : hint_albedo;
uniform sampler2D u_terrain_splatmap;
uniform mat4 u_terrain_inverse_transform;
uniform mat3 u_terrain_normal_basis;

uniform sampler2D u_ground_albedo_bump_0 : source_color;
uniform sampler2D u_ground_albedo_bump_1 : source_color;
uniform sampler2D u_ground_albedo_bump_2 : source_color;
uniform sampler2D u_ground_albedo_bump_3 : source_color;

uniform float u_ground_uv_scale = 20.0;
uniform bool u_depth_blending = true;
uniform bool u_triplanar = false;
// Each component corresponds to a ground texture. Set greater than zero to enable.
uniform vec4 u_tile_reduction = vec4(0.0, 0.0, 0.0, 0.0);
uniform float u_specular = 0.5;

// Shanshui uniforms
uniform sampler2D u_washi_texture : source_color, repeat_enable;
uniform float u_washi_scale = 10.0;
uniform vec4 u_shadow_color : source_color = vec4(0.12, 0.12, 0.25, 1.0); // Deep Indigo
uniform sampler2D u_shadow_noise;
uniform float u_shadow_edge_size = 0.1;
uniform float u_shadow_noise_scale = 1.0;

uniform vec3 u_cutout_player_position;
uniform vec3 u_cutout_camera_position;
uniform float u_cutout_radius = 0.0;
uniform float u_cutout_softness = 1.0;
uniform vec2 u_cutout_slope_cos_range = vec2(-1.0, 1.0);

// Calculates distance from a point (p) to the line segment (a to b)
float dist_segment(vec3 p, vec3 a, vec3 b) {
	vec3 pa = p - a;
	vec3 ba = b - a;
	float baba = dot(ba, ba);
	if (baba < 0.0001) {
		return length(pa);
	}
	float h = clamp(dot(pa, ba) / baba, 0.0, 1.0);
	return length(pa - ba * h);
}

#ifdef COLORMAP_PER_VERTEX
varying vec4 v_tint;
#endif
#ifdef SPLATMAP_PER_VERTEX
varying vec4 v_splat;
#endif
varying vec3 v_ground_uv;


vec3 unpack_normal(vec4 rgba) {
	vec3 n = rgba.xzy * 2.0 - vec3(1.0);
	// Had to negate Z because it comes from Y in the normal map,
	// and OpenGL-style normal maps are Y-up.
	n.z *= -1.0;
	return n;
}

// Blends weights according to the bump of detail textures,
// so for example it allows to have sand fill the gaps between pebbles
vec4 get_depth_blended_weights(vec4 splat, vec4 bumps) {
	float dh = 0.2;

	vec4 h = bumps + splat;

	// TODO Keep improving multilayer blending, there are still some edge cases...
	// Mitigation: nullify layers with near-zero splat
	h *= smoothstep(0, 0.05, splat);

	vec4 d = h + dh;
	d.r -= max(h.g, max(h.b, h.a));
	d.g -= max(h.r, max(h.b, h.a));
	d.b -= max(h.g, max(h.r, h.a));
	d.a -= max(h.g, max(h.b, h.r));

	return clamp(d, 0, 1);
}

vec3 get_triplanar_blend(vec3 world_normal) {
	vec3 blending = abs(world_normal);
	blending = normalize(max(blending, vec3(0.00001))); // Force weights to sum to 1.0
	float b = blending.x + blending.y + blending.z;
	return blending / vec3(b, b, b);
}

vec4 texture_triplanar(sampler2D tex, vec3 world_pos, vec3 blend) {
	vec4 xaxis = texture(tex, world_pos.yz);
	vec4 yaxis = texture(tex, world_pos.xz);
	vec4 zaxis = texture(tex, world_pos.xy);
	// blend the results of the 3 planar projections.
	return xaxis * blend.x + yaxis * blend.y + zaxis * blend.z;
}

vec4 depth_blend2(vec4 a, vec4 b, float t) {
	// https://www.gamasutra.com
	// /blogs/AndreyMishkinis/20130716/196339/Advanced_Terrain_Texture_Splatting.php
	float d = 0.1;
	float ma = max(a.a + (1.0 - t), b.a + t) - d;
	float ba = max(a.a + (1.0 - t) - ma, 0.0);
	float bb = max(b.a + t - ma, 0.0);
	return (a * ba + b * bb) / (ba + bb);
}

vec4 texture_antitile(sampler2D tex, vec2 uv) {
	float frequency = 2.0;
	float scale = 1.3;
	float sharpness = 0.7;

	// Rotate and scale UV
	float rot = 3.14 * 0.6;
	float cosa = cos(rot);
	float sina = sin(rot);
	vec2 uv2 = vec2(cosa * uv.x - sina * uv.y, sina * uv.x + cosa * uv.y) * scale;

	vec4 col0 = texture(tex, uv);
	vec4 col1 = texture(tex, uv2);
	//col0 = vec4(0.0, 0.0, 1.0, 1.0);
	// Periodically alternate between the two versions using a warped checker pattern
	float t = 0.5 + 0.5
		* sin(uv2.x * frequency + sin(uv.x) * 2.0)
		* cos(uv2.y * frequency + sin(uv.y) * 2.0);
	// Using depth blend because classic alpha blending smoothes out details
	return depth_blend2(col0, col1, smoothstep(0.5 * sharpness, 1.0 - 0.5 * sharpness, t));
}

void vertex() {
	vec2 cell_coords = (u_terrain_inverse_transform * MODEL_MATRIX * vec4(VERTEX, 1)).xz;
	// Must add a half-offset so that we sample the center of pixels,
	// otherwise bilinear filtering of the textures will give us mixed results.
	cell_coords += vec2(0.5);

	// Normalized UV
	UV = cell_coords / vec2(textureSize(u_terrain_heightmap, 0));

	// Height displacement
	float h = sample_heightmap(u_terrain_heightmap, UV);
	VERTEX.y = h;

	v_ground_uv = vec3(cell_coords.x, h * MODEL_MATRIX[1][1], cell_coords.y) / u_ground_uv_scale;

#ifdef COLORMAP_PER_VERTEX
	// Putting this in vertex saves 2 fetches from the fragment shader,
	// which is good for performance at a negligible quality cost,
	// provided that geometry is a regular grid that decimates with LOD.
	// (downside is LOD will also decimate tint and splat, but it's not bad overall)
	v_tint = texture(u_terrain_colormap, UV);
#endif
#ifdef SPLATMAP_PER_VERTEX
	v_splat = texture(u_terrain_splatmap, UV);
#endif

	// Need to use u_terrain_normal_basis to handle scaling.
	NORMAL = u_terrain_normal_basis * unpack_normal(texture(u_terrain_normalmap, UV));
}

void fragment() {
#ifndef COLORMAP_PER_VERTEX
	vec4 v_tint = texture(u_terrain_colormap, UV);
#endif

	if (v_tint.a < 0.5) {
		// TODO Add option to use vertex discarding instead, using NaNs
		discard;
	}

#ifndef SPLATMAP_PER_VERTEX
	vec4 v_splat = texture(u_terrain_splatmap, UV);
#endif

	vec3 terrain_normal_world =
		u_terrain_normal_basis * unpack_normal(texture(u_terrain_normalmap, UV));
	terrain_normal_world = normalize(terrain_normal_world);

	if (u_cutout_radius > 0.0) {
		vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float dist = dist_segment(wpos, u_cutout_camera_position, u_cutout_player_position);
		float softness = max(u_cutout_softness, 0.001);
		float opacity = smoothstep(u_cutout_radius, u_cutout_radius + softness, dist);

		if (terrain_normal_world.y < u_cutout_slope_cos_range.x || terrain_normal_world.y > u_cutout_slope_cos_range.y) {
			opacity = 1.0;
		}

		//ALPHA = opacity;
		if (opacity < 0.01) {
			discard;
		}
	}

	// TODO Detail should only be rasterized on nearby chunks (needs proximity management to switch shaders)

	vec2 ground_uv = v_ground_uv.xz;

	vec4 ab0, ab1, ab2, ab3;
	if (u_triplanar) {
		// Only do triplanar on one texture slot,
		// because otherwise it would be very expensive and cost many more ifs.
		// I chose the last slot because first slot is the default on new splatmaps,
		// and that's a feature used for cliffs, which are usually designed later.

		vec3 blending = get_triplanar_blend(terrain_normal_world);

		ab3 = texture_triplanar(u_ground_albedo_bump_3, v_ground_uv, blending);

	} else {
		if (u_tile_reduction[3] > 0.0) {
			ab3 = texture(u_ground_albedo_bump_3, ground_uv);
		} else {
			ab3 = texture_antitile(u_ground_albedo_bump_3, ground_uv);
		}
	}

	if (u_tile_reduction[0] > 0.0) {
		ab0 = texture_antitile(u_ground_albedo_bump_0, ground_uv);
	} else {
		ab0 = texture(u_ground_albedo_bump_0, ground_uv);
	}
	if (u_tile_reduction[1] > 0.0) {
		ab1 = texture_antitile(u_ground_albedo_bump_1, ground_uv);
	} else {
		ab1 = texture(u_ground_albedo_bump_1, ground_uv);
	}
	if (u_tile_reduction[2] > 0.0) {
		ab2 = texture_antitile(u_ground_albedo_bump_2, ground_uv);
	} else {
		ab2 = texture(u_ground_albedo_bump_2, ground_uv);
	}

	vec3 col0 = ab0.rgb;
	vec3 col1 = ab1.rgb;
	vec3 col2 = ab2.rgb;
	vec3 col3 = ab3.rgb;

	vec4 w;
	// TODO An #ifdef macro would be nice! Or copy/paste everything in a different shader...
	if (u_depth_blending) {
		w = get_depth_blended_weights(v_splat, vec4(ab0.a, ab1.a, ab2.a, ab3.a));
	} else {
		w = v_splat.rgba;
	}

	float w_sum = (w.r + w.g + w.b + w.a);

	ALBEDO = v_tint.rgb * (
		w.r * col0.rgb +
		w.g * col1.rgb +
		w.b * col2.rgb +
		w.a * col3.rgb) / w_sum;

	// Shanshui Modification: Apply Washi Paper Texture
	vec3 paper_tex = texture(u_washi_texture, v_ground_uv.xz * u_washi_scale).rgb;
	ALBEDO *= paper_tex;

	ROUGHNESS = 1.0;

	NORMAL = (VIEW_MATRIX * (vec4(terrain_normal_world, 0.0))).xyz;
	SPECULAR = u_specular;

	//ALBEDO = w.rgb;
	//ALBEDO = v_ground_uv.xyz;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	// Attenuation is 0.0 in cast shadows, 1.0 in fully lit areas
	float attenuation = ATTENUATION;

	// --- 1. The "Bleed" Edge ---
	// Sample noise for the wobbly edge.
	float edge_noise = texture(u_shadow_noise, v_ground_uv.xz * u_shadow_noise_scale).r;
	
	// Calculate the threshold. We perturb it around 0.0.
	float threshold = (edge_noise - 0.5) * u_shadow_edge_size;
	
	// Use a much sharper smoothstep (0.01 range) for a more defined, "painted" edge.
	float self_shadow_intensity = smoothstep(threshold, threshold + 0.01, NdotL);

	// Combine self-shadows with shadows cast by other objects.
	// This value is 1.0 for fully lit areas, and 0.0 for any type of shadow.
	float is_lit = self_shadow_intensity * attenuation;

	// --- 2. The Ink Wash Texture ---
	// We sample the SAME noise texture, but at a higher scale (e.g., 4x).
	// This creates a fine grain *inside* the shadow areas.
	float ink_grain = texture(u_shadow_noise, v_ground_uv.xz * u_shadow_noise_scale * 4.0).r;
	
	// Optional: Crunch the contrast of the grain to make it look more like pooled ink.
	ink_grain = smoothstep(0.3, 0.7, ink_grain);

	// The "inky" shadow color is your indigo color multiplied by this grain.
	// This makes the shadow look like it has texture and depth.
	vec3 inky_shadow_color = u_shadow_color.rgb * ink_grain;

	// --- 3. Final Mix ---
	// Normalize incoming light (compensating for Godot's Pi division).
	vec3 normalized_light_color = LIGHT_COLOR / 3.14159;

	// Mix between the textured ink shadow and the bright light based on lit status.
	vec3 final_light_col = mix(inky_shadow_color, normalized_light_color, is_lit);

	// Apply the result to the paper's ALBEDO.
	DIFFUSE_LIGHT += final_light_col * ALBEDO;
}
