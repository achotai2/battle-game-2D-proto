extends Node
class_name PlayerControls

@export var interactor: PlayerInteractor
@export var attackNode: Node
@export var movement: AgentMovement
@export var emit_zero_direction: bool = true
@export var deadzone: float = 0.15
@export var attack: StringName = &"attack"
@export var move_left: StringName = &"move_left"
@export var move_right: StringName = &"move_right"
@export var move_up: StringName = &"move_up"
@export var move_down: StringName = &"move_down"
@export var interact: StringName = &"interact"

signal input_changed

var _last_dir: Vector3 = Vector3.ZERO
var _is_moving: bool = false


func _ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	# Continuous movement belongs in physics tick
	var x: float = Input.get_axis(move_left, move_right)
	var y: float = Input.get_axis(move_up, move_down)
	var dir := Vector3(x, 0, y)

	# Optional deadzone (helps analog sticks; harmless for keyboard)
	if dir.length() < deadzone:
		dir = Vector3.ZERO
	else:
		dir = dir.normalized()

	# Emit only on change, or always (your choice)
	if emit_zero_direction:
		if dir != _last_dir:
			_last_dir = dir
			input_changed.emit()
	else:
		if dir != _last_dir:
			_last_dir = dir
			input_changed.emit()

		_is_moving = dir != Vector3.ZERO


func set_movement(m: AgentMovement) -> void:
	movement = m


# --- API FOR ADVISOR ---

func get_input_vector() -> Vector3:
	return _last_dir
