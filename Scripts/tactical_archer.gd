extends Node
class_name TacticalArcher
## Archer tactics:
## - If a target exists: keep distance (kite).
## - If too far: move closer to preferred range.
## - If too close: retreat away (flee).
## - If in the "sweet spot": stop (let weapon handle shooting when in range).
##
## This node does NOT fire the weapon. Weapon attacks whenever target is in its own range.
## This node only produces movement intent for AgentBase -> MinionPathfinding.

signal move_to_position(pos: Vector2)         # AgentBase should map to pathfinding.set_move_target_position(pos)
signal resume_patrol()

@export var preferred_range: float = 220.0     # ideal spacing
@export var min_range: float = 160.0           # if closer than this, retreat
@export var max_range: float = 280.0           # if farther than this, advance
@export var reposition_step: float = 140.0     # how far to step when adjusting position
@export_range(0.05, 1.0, 0.05) var update_rate: float = 0.20
@export var keep_line_of_fire: bool = true     # simple: bias sideways movement a bit
@export var movement: AgentMovement = null
@export var pathfinding: MinionPathfinding = null

var _target: Node2D = null
var _agent: Node2D = null
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = update_rate
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func set_agent(agent: Node2D) -> void:
	_agent = agent


func set_target(t: Node2D) -> void:
	# Called by detection node. Found a target.
	_target = t if is_instance_valid(t) else null

	if _target != null:
		if _timer.is_stopped():
			_timer.start(randf() * update_rate) # stagger
		_on_tick()
	else:
		_timer.stop()
		_resume_patrol()


func attack_finished() -> void:
	# Called by signal from animation when attack animation finishes.
	if is_instance_valid(movement):
		movement.un_freeze()
	elif is_instance_valid(_agent) and is_instance_valid(_agent.movement):
		_agent.movement.un_freeze()


func clear_target() -> void:
	# Called by detection node. Clear the target.
	_target = null
	_timer.stop()
	_resume_patrol()


func detection_refreshed(t: Node2D) -> void:
	# Called by detection node.
	if t != null:
		set_target(t)
	else:
		clear_target()


func _on_tick() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	if _target == null or not is_instance_valid(_target):
		_timer.stop()
		_resume_patrol()
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

	var desired_dir: Vector2

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
		var perp := Vector2(-dir_to.y, dir_to.x)
		# Choose a consistent side each tick based on target id (stable, no random jitter)
		var side := 1.0 if int(_target.get_instance_id()) % 2 == 0 else -1.0
		desired_dir = (desired_dir + perp * 0.35 * side).normalized()

	var dest := my_pos + desired_dir * reposition_step
	_move_to_position(dest)


func _move_to_position(dest: Vector2) -> void:
	if is_instance_valid(pathfinding):
		pathfinding.stop_meander()
		pathfinding.set_move_target_position(dest)
	if is_instance_valid(movement):
		movement.stop_meander()
	move_to_position.emit(dest)


func _resume_patrol() -> void:
	if is_instance_valid(pathfinding):
		pathfinding.clear_target()
		pathfinding.stop_meander()
	if is_instance_valid(movement):
		movement.make_meander()
	resume_patrol.emit()
