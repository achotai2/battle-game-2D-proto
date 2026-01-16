extends CanvasLayer
class_name InteractPrompt

@export_range(0.0, 64.0, 0.5) var bob_height: float = 6.0
@export_range(0.0, 10.0, 0.1) var bob_speed: float = 2.0
@export var circle: Sprite2D
@export var circleEmpty: Sprite2D

# Screen-space anchor for the whole prompt (CanvasLayer uses 'offset' in screen coords)
var _base_screen_pos: Vector2 = Vector2.ZERO
var _time: float = 0.0

func _ready() -> void:
	# Ensure this layer draws above the world (no scene edit needed)
	if layer < 10:
		layer = 10

	# Initialize to current offset
	_base_screen_pos = offset

	# Basic safety if sprites are missing
	if circle == null:
		push_warning("InteractPrompt: 'circle' Sprite2D export is not set.")
	if circleEmpty == null:
		push_warning("InteractPrompt: 'circleEmpty' Sprite2D export is not set.")

func _process(delta: float) -> void:
	_time += delta

	# Place the layer at the desired screen anchor
	offset = _base_screen_pos

	# Bob the visuals locally (so the whole layer stays anchored)
	var bob_y := sin(_time * bob_speed) * bob_height
	if circle:
		circle.position.y = bob_y
	if circleEmpty:
		circleEmpty.position.y = bob_y

# --- Public API ---

# Drive this from world logic each frame (or when target moves):
# world_pos: the target's world position
# percent_left: 0..1 for fill/progress
# world_offset: world-space offset above the target (e.g. (0, -32))
func set_world_target(world_pos: Vector2, percent_left: float, world_offset: Vector2 = Vector2(0, -32)) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var cam := viewport.get_camera_2d()
	if cam == null:
		return  # No camera yet (e.g., during scene boot); caller can retry
	_base_screen_pos = viewport.get_canvas_transform().xform(world_pos + world_offset)
	_set_percent(percent_left)

# If caller already has a screen-space point, use this:
func set_screen_target(screen_pos: Vector2, percent_left: float) -> void:
	_base_screen_pos = screen_pos
	_set_percent(percent_left)

# Show/hide helpers (UI layer visibility)
func show_prompt() -> void:
	visible = true

func hide_prompt() -> void:
	visible = false

# --- Internals ---

func _set_percent(percent_left: float) -> void:
	# Clamp
	var p := clamp(percent_left, 0.0, 1.0)

	# Scale the fill ring relative to the empty ring
	if circle and circleEmpty:
		circle.scale = circleEmpty.scale * p

# Optional convenience if you attach this prompt to a specific Node2D target at runtime:
func follow_target(target: Node2D, percent_left: float, world_offset: Vector2 = Vector2(0, -32)) -> void:
	if not is_instance_valid(target):
		return
	set_world_target(target.global_position, percent_left, world_offset)

# Optional: reset bobbing phase when (re)shown so it's more readable
func reset_bob_phase() -> void:
	_time = 0.0
