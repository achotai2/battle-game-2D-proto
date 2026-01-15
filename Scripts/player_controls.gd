extends Node
class_name PlayerControls

signal move_agent(direction: Vector2)

@export var interactor: PlayerInteractor
@export var emit_zero_direction: bool = true
@export var deadzone: float = 0.15
@export var attack: StringName = &"attack"
@export var move_left: StringName = &"move_left"
@export var move_right: StringName = &"move_right"
@export var move_up: StringName = &"move_up"
@export var move_down: StringName = &"move_down"
@export var interact: StringName = &"interact"

var _last_dir: Vector2 = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	# Continuous movement belongs in physics tick
	var x: float = Input.get_axis(move_left, move_right)
	var y: float = Input.get_axis(move_up, move_down)

	var dir := Vector2(x, y)

	# Optional deadzone (helps analog sticks; harmless for keyboard)
	if dir.length() < deadzone:
		dir = Vector2.ZERO
	else:
		dir = dir.normalized()

	# Emit only on change, or always (your choice)
	if emit_zero_direction:
		if dir != _last_dir:
			move_agent.emit(dir)
	else:
		if dir != Vector2.ZERO and dir != _last_dir:
			move_agent.emit(dir)

	_last_dir = dir


func _unhandled_input(event: InputEvent) -> void:
	# Discrete actions here so UI can consume input first
	if event.is_action_pressed(interact) and is_instance_valid(interactor):
		interactor.interaction_pressed()
		
	elif event.is_action_released(interact):
		interactor.interaction_released()
