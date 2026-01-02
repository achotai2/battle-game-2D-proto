shader_type canvas_item;

uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform vec3 new_color: source_color = vec3(1.0, 0.0, 0.0);
void fragment() {
	// Called for every pixel the material is visible on.
	COLOR = mix(COLOR, vec4(new_color, COLOR.a), progress * (1.0 - COLOR));
}
