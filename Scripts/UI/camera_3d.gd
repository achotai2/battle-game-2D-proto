extends Camera3D

@export var scroll_up: StringName = &"ScrollUp"
@export var scroll_down: StringName = &"ScrollDown"
@export var furthest_pos: Vector2 = Vector2(7.0, 8.0)
@export var closest_pos: Vector2 = Vector2(1.0, 2.0)
@export var shift_dist: float = 0.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(scroll_up):
		zoom_in()
	elif event.is_action_released(scroll_down):
		zoom_out()


func zoom_in() -> void:
	if position.y > closest_pos.x and position.z > closest_pos.y:
		position.y -= shift_dist
		position.z -= shift_dist


func zoom_out() -> void:
	if position.y < furthest_pos.x and position.z < furthest_pos.y:
		position.y += shift_dist
		position.z += shift_dist
