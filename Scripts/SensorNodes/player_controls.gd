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
var _interaction_active: bool = false
var controls_priority: int = 99999


func _ready() -> void:
	_bind_interactor()


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
			if dir == Vector3.ZERO:
				_unpause_attack()
			else:
				_pause_attack()

			_last_dir = dir
			input_changed.emit()
	else:
		if dir != _last_dir:
			_last_dir = dir
			input_changed.emit()

		_is_moving = dir != Vector3.ZERO
		if _is_moving:
			_pause_attack()
		elif not _interaction_active:
			_unpause_attack()


func set_interactor(value: PlayerInteractor) -> void:
	interactor = value
	_bind_interactor()


func set_attackNode(a: Node) -> void:
	attackNode = a


func set_movement(m: AgentMovement) -> void:
	movement = m


func _bind_interactor() -> void:
	if interactor:
		if not interactor.interaction_started.is_connected(_on_interaction_started):
			interactor.interaction_started.connect(_on_interaction_started)
		if not interactor.interaction_finished.is_connected(_on_interaction_finished):
			interactor.interaction_finished.connect(_on_interaction_finished)
		if not interactor.interaction_suspended.is_connected(_on_interaction_finished):
			interactor.interaction_suspended.connect(_on_interaction_finished)


func _unhandled_input(event: InputEvent) -> void:
	# Discrete actions here so UI can consume input first
	if event.is_action_pressed(interact) and interactor:
		interactor.interaction_pressed()
	elif event.is_action_released(interact):
		interactor.interaction_released()


func _pause_attack() -> void:
	if attackNode:
		if attackNode.has_method("pause_attack"):
			attackNode.pause_attack(controls_priority)


func _unpause_attack() -> void:
	if attackNode:
		if attackNode.has_method("restart_attack"):
			attackNode.restart_attack(controls_priority)


func _attacking() -> bool:
	if attackNode and attackNode.has_method("am_i_attacking"):
		return attackNode.am_i_attacking()
	else:
		return false


func _interacting() -> bool:
	return interactor.am_i_interacting()


func _on_interaction_started(_target: Interactable) -> void:
	_interaction_active = true
	_pause_attack()


func _on_interaction_finished(_target: Interactable) -> void:
	_interaction_active = false
	if not _is_moving:
		_unpause_attack()

# --- API FOR ADVISOR ---

func get_input_vector() -> Vector3:
	return _last_dir

func is_attack_pressed() -> bool:
	# For now just return if attack button is held?
	# Or if auto-attack is enabled?
	# The game seems to have auto-attack.
	return false # AdvisorPlayer will rely on AdvisorAttack logic? No, Player is boss.
	# Actually, PlayerControls calls attackNode.restart_attack() which enabled auto-attack logic in Weapon.
	# But Weapon is now passive.
	# So AdvisorPlayer needs to tell Brain "Attack if possible".
	# If Player moves, Intent(MOVE).
	# If Player stops, Intent(IDLE) or Intent(ATTACK)?
	# "AdvisorPlayer... checks AgentControls... returns intent based on input."
	# If input is zero, Player intends to IDLE or ATTACK (if enemy near).
	# So AdvisorPlayer should probably defer to AdvisorAttack if idle?
	# But AdvisorPlayer has priority 100.
	# If AdvisorPlayer returns IDLE, Brain might pick AdvisorAttack (Priority 10).
	# Ah! If AdvisorPlayer returns intent only when input exists.
	# If input is zero, AdvisorPlayer returns null?
	# Then Brain falls back to other advisors.
	# BUT `AdvisorPlayer` is the ONLY advisor for Player role in my `apply_role`.
	# So I should add `AdvisorAttack` to Player too?
	# If I add `AdvisorAttack` to Player, then when Player stops, `AdvisorAttack` takes over and attacks nearby enemies.
	# This mimics the "auto-attack when stopped" behavior.
	# Perfect.
