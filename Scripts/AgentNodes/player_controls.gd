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
var _is_moving: bool = false
var _interaction_active: bool = false


func _ready() -> void:
	_bind_interactor()


func set_interactor(value: PlayerInteractor) -> void:
	interactor = value
	_bind_interactor()


func set_attackNode(a: Node) -> void:
	attackNode = a


func set_movement(m: AgentMovement) -> void:
	movement = m


func _bind_interactor() -> void:
	if is_instance_valid(interactor):
		if not interactor.interaction_started.is_connected(_on_interaction_started):
			interactor.interaction_started.connect(_on_interaction_started)
		if not interactor.interaction_finished.is_connected(_on_interaction_finished):
			interactor.interaction_finished.connect(_on_interaction_finished)
		if not interactor.interaction_suspended.is_connected(_on_interaction_finished):
			interactor.interaction_suspended.connect(_on_interaction_finished)


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
				movement.command_player_direction(dir, 5)
	else:
		if dir != Vector2.ZERO and dir != _last_dir:
			if is_instance_valid(movement):
				movement.command_player_direction(dir, 5)

	_is_moving = dir != Vector2.ZERO
	if _is_moving:
		_pause_attack()
	elif not _interaction_active:
		_unpause_attack()

	_last_dir = dir


func _unhandled_input(event: InputEvent) -> void:
	# Discrete actions here so UI can consume input first
	if event.is_action_pressed(interact) and is_instance_valid(interactor):
		interactor.interaction_pressed()
	elif event.is_action_released(interact):
		interactor.interaction_released()


func _pause_attack() -> void:
	if is_instance_valid(attackNode):
		attackNode.pause_attack()


func _unpause_attack() -> void:
	if is_instance_valid(attackNode):
		attackNode.restart_attack()


func _on_interaction_started(_target: Interactable) -> void:
	_interaction_active = true
	_pause_attack()


func _on_interaction_finished(_target: Interactable) -> void:
	_interaction_active = false
	if not _is_moving:
		_unpause_attack()
