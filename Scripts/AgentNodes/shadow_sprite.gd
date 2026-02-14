extends Node2D

@export var main_body_path: NodePath
@onready var main_body = get_node_or_null(main_body_path)

func _ready() -> void:
	if has_node("/root/Sun"):
		Sun.sun_updated.connect(_on_sun_updated)
		# Force initial update
		_on_sun_updated(Color.WHITE, Sun.current_shadow_color)

func _on_sun_updated(_ambient_color: Color, shadow_color: Color) -> void:
	# --- 1. OPTIMIZATION CHECK ---
	if shadow_color.r > 0.98:
		visible = false
		return # Stop processing math
	else:
		visible = true

	# --- 2. SYNC ANIMATION ---
	# Note: Animation sync code was commented out in original file.
	# If needed, it would require per-frame processing (process or signal from body).

	# --- 3. MATH & TRANSFORM ---
	var angle_rad = deg_to_rad(Sun.current_sun_angle)
	var length = Sun.current_shadow_length
	var width = Sun.shadow_width

	var shadow_vec = Vector2(sin(angle_rad), -cos(angle_rad)) * length

	transform.x = Vector2(width, 0.0)
	transform.y = -shadow_vec 
	position = Vector2.ZERO
