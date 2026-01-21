extends Node
class_name TacticalPeasant

signal chase_target(target: Node2D)
signal move_to_position(pos: Vector2)

@export var flee_distance: float = 220.0
@export var flee_margin: float = 99999.0
@export_range(0.05, 2.0, 0.05) var flee_update: float = 0.25
@export var movement: AgentMovement = null

var _target: Node2D = null
var _agent: Node2D = null
var _timer: Timer


func _ready() -> void:
	_agent = get_parent() as Node2D

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = flee_update
	_timer.timeout.connect(_on_flee_tick)
	add_child(_timer)


func set_agent(agent: Node2D) -> void:
	_agent = agent

	# If we gain a castle at any time, immediately run home.
	if is_instance_valid(_agent.return_castle()):
		_timer.stop()
	elif _target != null:
		_start_flee()


func set_target(t: Node2D) -> void:
	# Called by detection node. Found a target.
	_target = t if is_instance_valid(t) else null

	if is_instance_valid(_agent.return_castle()):
		_timer.stop()
		_chase_target(_agent.return_castle())
		return

	if _target != null:
		_start_flee()
	else:
		_timer.stop()


func clear_target() -> void:
	# Called by detection node. Clear the target.
	_target = null
	_timer.stop()

	if is_instance_valid(_agent.return_castle()):
		_chase_target(_agent.return_castle())


func detection_refreshed(t: Node2D) -> void:
	# Called by detection node.
	pass


func _start_flee() -> void:
	if _timer.is_stopped():
		_timer.start(randf() * flee_update) # stagger
	_on_flee_tick()


func _on_flee_tick() -> void:
	# If we have a castle, always prioritize running home.
	if is_instance_valid(_agent.return_castle()):
		_timer.stop()
		_chase_target(_agent.return_castle())
		return

	if _agent == null or not is_instance_valid(_agent):
		return

	if _target == null or not is_instance_valid(_target):
		_timer.stop()
		return

	var to_enemy: Vector2 = _target.global_position - _agent.global_position
	var dist: float = to_enemy.length()

	# If already far enough, don't spam new destinations.
	if dist >= (flee_distance + flee_margin):
		return

	var away_dir := (-to_enemy).normalized()
	if away_dir == Vector2.ZERO:
		away_dir = Vector2.RIGHT

	var flee_point := _agent.global_position + away_dir * flee_distance
	_move_to_position(flee_point)


func _chase_target(target: Node2D) -> void:
	if is_instance_valid(movement):
		movement.command_chase_target(target, 5)
	chase_target.emit(target)


func _move_to_position(pos: Vector2) -> void:
	if is_instance_valid(movement):
		movement.command_move_to_position(pos, 5)
	move_to_position.emit(pos)
