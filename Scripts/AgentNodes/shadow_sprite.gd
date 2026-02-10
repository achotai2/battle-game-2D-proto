extends Node2D

@export var main_body_path: NodePath
@onready var main_body = get_node_or_null(main_body_path)

func _process(_delta):
	# --- 1. OPTIMIZATION CHECK ---
	# If the shadow length is near max (Sunrise/Sunset/Night), 
	# check if we should even be visible.
	
	# If the global shadow color is White (Invisible), hide the sprite entirely.
	# We check if the Red channel is > 0.95 (Almost White).
	# This saves the GPU from drawing invisible pixels.
	var color_check = RenderingServer.global_shader_parameter_get("global_shadow_color")
	if color_check is Color and color_check.r > 0.98:
		visible = false
		return # Stop processing math
	else:
		visible = true

	# --- 2. SYNC ANIMATION ---
	if main_body:
		if "animation" in main_body and "animation" in self:
			self.animation = main_body.animation
		if "frame" in main_body and "frame" in self:
			self.frame = main_body.frame
		if "flip_h" in main_body and "flip_h" in self:
			self.flip_h = main_body.flip_h

	# --- 3. MATH & TRANSFORM (Existing Code) ---
	var angle_rad = deg_to_rad(Sun.current_sun_angle)
	var length = Sun.current_shadow_length
	var width = Sun.shadow_width

	var shadow_vec = Vector2(sin(angle_rad), -cos(angle_rad)) * length

	transform.x = Vector2(width, 0.0)
	transform.y = -shadow_vec 
	position = Vector2.ZERO
