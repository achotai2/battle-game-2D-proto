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
			if is_instance_valid(movement):
				movement.player_controlled_movement(dir)
	else:
		if dir != Vector2.ZERO and dir != _last_dir:
			if is_instance_valid(movement):
				movement.player_controlled_movement(dir)

	if dir != Vector2.ZERO:
		_pause_attack()
	else:
		_unpause_attack()

	_last_dir = dir


func _unhandled_input(event: InputEvent) -> void:
	# Discrete actions here so UI can consume input first
	if event.is_action_pressed(interact) and is_instance_valid(interactor):
		interactor.interaction_pressed()
		_pause_attack()
	elif event.is_action_released(interact):
		interactor.interaction_released()
		_unpause_attack()


func _pause_attack() -> void:
	if is_instance_valid(attack):
		attackNode.pause_attack()


func _unpause_attack() -> void:
	if is_instance_valid(attack):
		attackNode.restart_attack()
