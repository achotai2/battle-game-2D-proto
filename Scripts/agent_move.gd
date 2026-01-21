extends Node
class_name AgentMovement

@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0

@export var can_meander: bool = false
@export var agent: Node2D = null
@export var animation: AgentAnimate = null
@export var pathfinding: MinionPathfinding = null

# Optional smoothing (helps crowd jitter)
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

var _current_velocity: Vector2 = Vector2.ZERO
var _action_state: int = 0
var _pf_velocity: Vector2 = Vector2.ZERO

enum OrderType { NONE, MEANDER, MOVE_TO_POS, CHASE_NODE, RAW_VELOCITY, PLAYER_DIRECTION }

var _order_type: int = OrderType.NONE
var _order_priority: int = -1
var _order_target_pos: Vector2 = Vector2.ZERO
var _order_target_node: Node2D = null
var _order_raw_velocity: Vector2 = Vector2.ZERO
var _order_direction: Vector2 = Vector2.ZERO

const LOCK_ATTACK := &"attack"
const LOCK_INTERACT := &"interact"
const LOCK_WORK := &"work"
const LOCK_STUN := &"stun"

var _freeze_locks: Dictionary = {}

const ACTION_NONE := 0
const ACTION_ATTACK := 1
const ACTION_WORK := 2
const ACTION_INTERACT := 3


func _ready() -> void:
	_bind_pathfinding()


# --- Public control API ---

func set_animation(anim: AgentAnimate) -> void:
	if is_instance_valid(animation):
		if animation.attackAnimationFinished.is_connected(_on_attack_animation_finished):
			animation.attackAnimationFinished.disconnect(_on_attack_animation_finished)
		if animation.interactAnimationFinished.is_connected(_on_interact_animation_finished):
			animation.interactAnimationFinished.disconnect(_on_interact_animation_finished)

	animation = anim

	if is_instance_valid(animation):
		if not animation.attackAnimationFinished.is_connected(_on_attack_animation_finished):
			animation.attackAnimationFinished.connect(_on_attack_animation_finished)
		if not animation.interactAnimationFinished.is_connected(_on_interact_animation_finished):
			animation.interactAnimationFinished.connect(_on_interact_animation_finished)


func set_pathfinding(value: MinionPathfinding) -> void:
	if pathfinding == value:
		return
	_unbind_pathfinding()
	pathfinding = value
	_bind_pathfinding()


func is_frozen() -> bool:
	return _freeze_locks.size() > 0


func freeze(reason: StringName = &"generic") -> void:
	# Called by action start or external systems.
	_freeze_locks[reason] = true
	_current_velocity = Vector2.ZERO
	_notify_moved(Vector2.ZERO)


func unfreeze(reason: StringName = &"generic") -> void:
	# Called to unfreeze movement.
	# Can be called by signal from agent animation when a frozen animation is finished.
	_freeze_locks.erase(reason)
	if reason == LOCK_ATTACK or reason == LOCK_WORK or reason == LOCK_INTERACT or reason == &"generic":
		_action_state = ACTION_NONE


func clear_freeze_locks(keep: Array[StringName] = []) -> void:
	for lock in _freeze_locks.keys():
		if not keep.has(lock):
			_freeze_locks.erase(lock)
	_action_state = ACTION_NONE


func debug_freeze_locks() -> Array[StringName]:
	return _freeze_locks.keys()


func _to_string() -> String:
	return "AgentMovement locks=%s" % [debug_freeze_locks()]


func start_attack(target: Node2D) -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_ATTACK:
		return false
	if _action_state == ACTION_ATTACK and is_frozen():
		return true

	_action_state = ACTION_ATTACK
	freeze(LOCK_ATTACK)
	var started := false
	if is_instance_valid(animation):
		started = animation.play_attack(target)

	if not started:
		unfreeze(LOCK_ATTACK)
	return started


func start_work() -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_WORK:
		return false
	if _action_state == ACTION_WORK and is_frozen():
		return true

	_action_state = ACTION_WORK
	freeze(LOCK_WORK)

	if is_instance_valid(animation):
		animation.play_work()

	return true


func start_interaction() -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_INTERACT:
		return false
	if _action_state == ACTION_INTERACT and is_frozen():
		return true

	_action_state = ACTION_INTERACT
	freeze(LOCK_INTERACT)
	var started := false
	if is_instance_valid(animation):
		started = animation.play_work()

	if not started:
		unfreeze(LOCK_INTERACT)
	return started


# --- Movement entry points ---

# Preferred: already-scaled velocity (pathfinding + avoidance)
func move_with_velocity(desired_velocity: Vector2, delta: float) -> void:
	if is_frozen():
		_current_velocity = Vector2.ZERO
		_notify_moved(Vector2.ZERO)
		return

	var speed_cap := meander_speed if _order_type == OrderType.MEANDER else max_speed
	var v := desired_velocity

	# Clamp to current speed cap
	var len := v.length()
	if len > speed_cap:
		v = v * (speed_cap / len)

	# Optional acceleration smoothing
	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	_notify_moved(_current_velocity)


func _on_pf_desired_velocity(v: Vector2) -> void:
	_pf_velocity = v


# Convenience: direction in (unit or not)
func move_in_direction(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		move_with_velocity(Vector2.ZERO, delta)
	else:
		move_with_velocity(direction.normalized() * max_speed, delta)


func return_speed() -> float:
	if is_frozen():
		return 0.0
	if _order_type == OrderType.MEANDER:
		return meander_speed
	return max_speed


func set_my_agent(owner_agent: Node2D) -> void:
	agent = owner_agent


func _on_attack_animation_finished() -> void:
	if _action_state == ACTION_ATTACK:
		unfreeze(LOCK_ATTACK)


func _on_interact_animation_finished() -> void:
	if _action_state == ACTION_WORK or _action_state == ACTION_INTERACT:
		if _action_state == ACTION_WORK:
			unfreeze(LOCK_WORK)
		else:
			unfreeze(LOCK_INTERACT)


func _notify_moved(vel: Vector2) -> void:
	if is_instance_valid(agent):
		agent.velocity = vel

	if is_instance_valid(animation):
		animation.agent_moved(vel)


func tick(delta: float) -> void:
	if is_frozen():
		move_with_velocity(Vector2.ZERO, delta)
		return

	if _order_type == OrderType.NONE and can_meander:
		_start_self_meander()

	match _order_type:
		OrderType.MEANDER, OrderType.MOVE_TO_POS, OrderType.CHASE_NODE:
			if is_instance_valid(pathfinding) and is_instance_valid(agent):
				pathfinding.tick(agent.global_position, return_speed(), delta)
				move_with_velocity(_pf_velocity, delta)
			else:
				move_with_velocity(Vector2.ZERO, delta)
		OrderType.PLAYER_DIRECTION:
			move_in_direction(_order_direction, delta)
		OrderType.RAW_VELOCITY:
			move_with_velocity(_order_raw_velocity, delta)
		OrderType.NONE:
			move_with_velocity(Vector2.ZERO, delta)


func command_move_to_position(pos: Vector2, priority: int = 5) -> void:
	if not _accept_order(priority):
		return

	_order_type = OrderType.MOVE_TO_POS
	_order_target_pos = pos
	_order_target_node = null
	_order_raw_velocity = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()
	if is_instance_valid(pathfinding):
		pathfinding.set_move_target_position(pos)


func command_chase_target(node: Node2D, priority: int = 5) -> void:
	if not _accept_order(priority):
		return

	_order_type = OrderType.CHASE_NODE
	_order_target_node = node
	_order_target_pos = Vector2.ZERO
	_order_raw_velocity = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()
	if is_instance_valid(pathfinding):
		pathfinding.set_chase_target(node)


func command_move_velocity(vel: Vector2, priority: int = 5) -> void:
	if not _accept_order(priority):
		return

	_order_type = OrderType.RAW_VELOCITY
	_order_raw_velocity = vel
	_order_target_node = null
	_order_target_pos = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()
	if is_instance_valid(pathfinding):
		pathfinding.clear_target()


func command_player_direction(dir: Vector2, priority: int = 5) -> void:
	if not _accept_order(priority):
		return

	_order_type = OrderType.PLAYER_DIRECTION
	_order_direction = dir
	_order_target_node = null
	_order_target_pos = Vector2.ZERO
	_order_raw_velocity = Vector2.ZERO
	_disable_meander()
	if is_instance_valid(pathfinding):
		pathfinding.clear_target()


func clear_movement_order(priority: int = 5) -> void:
	if priority < _order_priority:
		return

	_order_type = OrderType.NONE
	_order_priority = -1
	_order_target_pos = Vector2.ZERO
	_order_target_node = null
	_order_raw_velocity = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()
	if is_instance_valid(pathfinding):
		pathfinding.clear_target()


func _accept_order(priority: int) -> bool:
	if priority < _order_priority:
		return false
	_order_priority = priority
	return true


func _disable_meander() -> void:
	if is_instance_valid(pathfinding):
		pathfinding.set_meander(false)


func _start_self_meander() -> void:
	_order_type = OrderType.MEANDER
	_order_priority = 0
	if is_instance_valid(pathfinding):
		pathfinding.set_meander(true)


func _bind_pathfinding() -> void:
	if not is_instance_valid(pathfinding):
		return
	if not pathfinding.desired_velocity.is_connected(_on_pf_desired_velocity):
		pathfinding.desired_velocity.connect(_on_pf_desired_velocity)
	if _order_type == OrderType.MEANDER and can_meander:
		pathfinding.set_meander(true)
	else:
		pathfinding.set_meander(false)


func _unbind_pathfinding() -> void:
	if is_instance_valid(pathfinding):
		if pathfinding.desired_velocity.is_connected(_on_pf_desired_velocity):
			pathfinding.desired_velocity.disconnect(_on_pf_desired_velocity)
