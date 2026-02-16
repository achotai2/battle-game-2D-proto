extends Node
class_name TacticalArcher
## Archer tactics:
## - If a target exists: keep distance (kite).
## - If too far: move closer to preferred range.
## - If too close: retreat away (flee).
## - If in the "sweet spot": stop (let weapon handle shooting when in range).
##
## This node does NOT fire the weapon. Weapon attacks whenever target is in its own range.
## This node only produces movement intent for AgentBase -> AgentMovement.

@export var preferred_range: float = 220.0     # ideal spacing
@export var min_range: float = 160.0           # if closer than this, retreat
@export var max_range: float = 280.0           # if farther than this, advance
@export var reposition_step: float = 140.0     # how far to step when adjusting position
@export_range(0.05, 1.0, 0.05) var update_rate: float = 0.20
@export var keep_line_of_fire: bool = true     # simple: bias sideways movement a bit
@export var movement: AgentMovement = null
@export var archer_priority: int = 6

var _target: CharacterBody3D = null
var _agent: CharacterBody3D = null
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = update_rate
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func set_agent(agent: CharacterBody3D) -> void:
	_agent = agent


func set_target(t: CharacterBody3D) -> void:
	# Called by detection node. Found a target.
	_target = t if is_instance_valid(t) else null

	if _target != null:
		if _timer.is_stopped():
			_timer.start(randf() * update_rate) # stagger
		_on_tick()
	else:
		_timer.stop()


func set_movement(m: AgentMovement) -> void:
	movement = m


func clear_target() -> void:
	# Called by detection node. Clear the target.
	_target = null
	_timer.stop()


func detection_refreshed(t: CharacterBody3D) -> void:
	# Called by detection node.
	pass


func _on_tick() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	if _target == null or not is_instance_valid(_target):
		_timer.stop()
		return

	var my_pos := _agent.global_position
	var tar_pos := _target.global_position
	var to_target := tar_pos - my_pos
	var dist := to_target.length()

	if dist < 0.001:
		return

	var dir_to := to_target / dist
	var dir_away := -dir_to

	# In sweet spot: don't issue move commands (prevents jitter).
	if dist >= min_range and dist <= max_range:
		# Optional: you might want to explicitly "stop" by moving to current pos,
		# but that can cause repathing noise. Usually better to do nothing.
		return

	var desired_dir: Vector3

	if dist < min_range:
		# Too close: retreat
		desired_dir = dir_away
	elif dist > max_range:
		# Too far: advance
		desired_dir = dir_to
	else:
		desired_dir = dir_away

	# Slight sideways bias to avoid straight-line oscillation (kite feel).
	if keep_line_of_fire:
		var perp := Vector3(-dir_to.y, dir_to.x)
		# Choose a consistent side each tick based on target id (stable, no random jitter)
		var side := 1.0 if int(_target.get_instance_id()) % 2 == 0 else -1.0
		desired_dir = (desired_dir + perp * 0.35 * side).normalized()

	var dest := my_pos + desired_dir * reposition_step
	_move_to_position(dest)


func _move_to_position(dest: Vector3) -> void:
	if is_instance_valid(movement):
		movement.command_move_to_position(dest, archer_priority)
