extends Node
class_name AgentMovement

signal move_to_pos_finished(agent: Node2D)

@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0

@export var can_meander: bool = true
@export var agent: Node2D = null
@export var animation: AgentAnimate = null

# --- Pathfinding Refs ---
@export var nav_agent: NavigationAgent2D

# --- Repath tuning ---
@export_range(0.05, 20.0, 0.05) var repath_interval: float = 1.0
@export_range(1.0, 200.0, 1.0) var target_repath_distance: float = 250.0

# --- Stuck detection ---
@export_range(0.1, 2.0, 0.05) var stuck_time: float = 1.0
@export_range(0.0, 200.0, 1.0) var min_progress_per_sec: float = 8.0

# --- Arrival ---
@export_range(0.0, 200.0, 1.0) var slow_radius: float = 0.0

# Optional smoothing (helps crowd jitter)
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

# --- Patrol / meander ---
@export var assigned_castle: Node2D
@export_range(0.0, 2000.0, 10.0) var patrol_radius: float = 500.0
@export_range(0.0, 200.0, 1.0) var patrol_arrival_radius: float = 50.0
@export_range(0.0, 200.0, 1.0) var path_desired_distance: float = 50.0
@export_range(0.0, 10.0, 0.1) var patrol_pause_seconds: float = 0.5
@export_range(1, 20, 1) var patrol_pick_attempts: int = 8

var meander_enabled: bool = false

# Timers / tracking
var _repath_timer: Timer
var _patrol_pause_timer: Timer
var _last_my_pos: Vector2 = Vector2.ZERO
var _stuck_accum: float = 0.0

#var _target_node: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _last_target_pos: Vector2 = Vector2.ZERO

var _current_velocity: Vector2 = Vector2.ZERO
#var _pf_velocity: Vector2 = Vector2.ZERO
var _last_anim_velocity: Vector2 = Vector2(INF, INF)
const ANIM_JITTER_THRESHOLD_SQ: float = 4.0 # (2 pixels)^2

enum OrderType { NONE, MEANDER, MOVE_TO_POS, CHASE_NODE, RAW_VELOCITY, PLAYER_DIRECTION, FROZEN }

var _order_type: OrderType = OrderType.NONE
var _order_priority: int = -1
var _order_target_pos: Vector2 = Vector2.ZERO
var _order_target_node: Node2D = null
var _order_raw_velocity: Vector2 = Vector2.ZERO
var _order_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	if not nav_agent:
		push_warning("AgentMovement: nav_agent is not assigned.")
		return

	nav_agent.avoidance_enabled = true
	nav_agent.path_desired_distance = path_desired_distance
	nav_agent.target_desired_distance = patrol_arrival_radius
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_nav_finished)

	_repath_timer = Timer.new()
	_repath_timer.one_shot = false
	_repath_timer.wait_time = repath_interval
	_repath_timer.timeout.connect(_on_repath_tick)
	add_child(_repath_timer)
	_repath_timer.start(randf() * repath_interval) # stagger

	_patrol_pause_timer = Timer.new()
	_patrol_pause_timer.one_shot = true
	_patrol_pause_timer.timeout.connect(_on_patrol_pause_timeout)
	add_child(_patrol_pause_timer)


# --- Public control API ---

func tick(delta: float) -> void:
	if is_frozen():
		move_with_velocity(Vector2.ZERO, delta)
		return

	if _order_type == OrderType.NONE and can_meander:
		_start_self_meander()

	# Process movement logic based on order type
	match _order_type:
		OrderType.MEANDER, OrderType.MOVE_TO_POS, OrderType.CHASE_NODE:
			if nav_agent and agent:
				_process_pathfinding(agent.global_position, return_speed(), delta)
				# move_with_velocity is called via _on_velocity_computed callback from nav_agent
			else:
				move_with_velocity(Vector2.ZERO, delta)

		OrderType.PLAYER_DIRECTION:
			move_in_direction(_order_direction, delta)

		OrderType.RAW_VELOCITY:
			move_with_velocity(_order_raw_velocity, delta)

		OrderType.NONE:
			move_with_velocity(Vector2.ZERO, delta)

	_update_visuals()


func set_animation(anim: AgentAnimate) -> void:
	animation = anim


func is_frozen() -> bool:
	return _order_type == OrderType.FROZEN


# --- Movement entry points ---

# Preferred: already-scaled velocity (pathfinding + avoidance)
func move_with_velocity(desired_velocity: Vector2, delta: float) -> void:
	if is_frozen():
		_current_velocity = Vector2.ZERO
		if agent: agent.velocity = Vector2.ZERO
		return

	# 1. OPTIMIZATION: Use C++ optimized functions instead of manual math
	var speed_cap := meander_speed if _order_type == OrderType.MEANDER else max_speed

	# This single line replaces your manual length() check and division
	var v := desired_velocity.limit_length(speed_cap)

	# 2. OPTIMIZATION: Fast path for no smoothing
	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	# 3. APPLY PHYSICS DIRECTLY (Skip _notify_moved function overhead)
	# We assume 'agent' is valid because this script is likely a child of agent
	if agent:
		agent.velocity = _current_velocity

	# NOTE: We DO NOT update animation here anymore.
	# That is now handled in tick() to prevent signal thrashing.


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# 1. OPTIMIZATION: Skip delta fetching if no acceleration is used
	if accel == 0.0:
		move_with_velocity(safe_velocity, 0.0)
	else:
		# Only fetch delta if we actually need it for smoothing
		move_with_velocity(safe_velocity, get_physics_process_delta_time())


func _on_nav_finished() -> void:
	if _order_type == OrderType.MOVE_TO_POS:
		_order_type = OrderType.NONE
		move_to_pos_finished.emit(get_parent())
		move_with_velocity(Vector2.ZERO, 0.0)

	elif _order_type == OrderType.MEANDER:
		move_with_velocity(Vector2.ZERO, 0.0)
		if not _patrol_pause_timer.is_stopped():
			return

		if patrol_pause_seconds > 0.0:
			_patrol_pause_timer.start(patrol_pause_seconds)
		else:
			_pick_new_patrol_point()


func _on_patrol_pause_timeout() -> void:
	if _order_type == OrderType.MEANDER:
		_pick_new_patrol_point()


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


func _update_visuals() -> void:
	# Call this at the end of your tick(delta) function!
	if not animation:
		return

	# 1. OPTIMIZATION: Jitter Filter
	# RVO Avoidance creates tiny micro-movements. We don't want to
	# retune the AnimationTree for a 0.1 pixel change.

	# Check squared distance to avoid Sqrt()
	if _current_velocity.distance_squared_to(_last_anim_velocity) > ANIM_JITTER_THRESHOLD_SQ:
		animation.agent_moved(_current_velocity)
		_last_anim_velocity = _current_velocity

	# Edge case: If we stopped completely, force an update to play Idle
	elif _current_velocity.is_zero_approx() and not _last_anim_velocity.is_zero_approx():
		animation.agent_moved(Vector2.ZERO)
		_last_anim_velocity = Vector2.ZERO


func _accept_order(priority: int) -> bool:
	if priority < _order_priority:
		return false
	_order_priority = priority
	return true


func _disable_meander() -> void:
	pass


func _start_self_meander() -> void:
	if not is_instance_valid(assigned_castle):
		can_meander = false
	_order_type = OrderType.MEANDER
	_order_priority = 0
	_pick_new_patrol_point()


func no_order_check() -> bool:
	return _order_type == OrderType.NONE


func _pick_new_patrol_point() -> void:
	if _order_type != OrderType.MEANDER:
		return
	if not is_instance_valid(assigned_castle):
		# No castle -> can't patrol; just stop. But set target to current to avoid drift/errors.
		if is_instance_valid(agent):
			_set_target_pos(agent.global_position)
		return

	var center := assigned_castle.global_position

	# Try a few random points; choose the first that is likely reachable.
	for i in range(patrol_pick_attempts):
		# Random point inside a circle (uniform-ish)
		var angle := randf() * TAU
		var r := sqrt(randf()) * patrol_radius
		var candidate := center + Vector2(cos(angle), sin(angle)) * r
		var map = nav_agent.get_navigation_map()
		candidate = NavigationServer2D.map_get_closest_point(map, candidate)

		# Basic sanity: avoid choosing basically the same target
		# Bolt: Squared distance check (8^2 = 64)
		if candidate.distance_squared_to(_target_pos) < 64.0:
			continue

		_order_target_pos = candidate
		_set_target_pos(candidate)
		return

	# Fallback: just stand near castle
	_order_target_pos = center
	_set_target_pos(center)


#---- MOVEMENT COMMAND FUNCTIONS ----

func command_start_attack(target: Node2D, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	command_move_velocity(Vector2.ZERO, priority)
	_order_type = OrderType.FROZEN

	if animation:
		animation.play_attack(target)

	return true


func command_start_interaction(priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	command_move_velocity(Vector2.ZERO, priority)
	_order_type = OrderType.FROZEN

	if animation:
		animation.play_work()

	return true


func command_start_work(priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	command_move_velocity(Vector2.ZERO, priority)
	_order_type = OrderType.FROZEN

	if animation:
		animation.play_work()

	return true


func command_move_to_position(pos: Vector2, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.MOVE_TO_POS
	_order_target_pos = pos
	_order_target_node = null
	_order_raw_velocity = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()

	_set_target_pos(pos)
		
	return true


func command_chase_target(node: Node2D, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.CHASE_NODE
	_order_target_node = node
	_order_target_pos = Vector2.ZERO
	_order_raw_velocity = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()

	_refresh_target_and_repath(true)

	return true


func command_move_velocity(vel: Vector2, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.RAW_VELOCITY
	_order_raw_velocity = vel
	_order_target_node = null
	_order_target_pos = Vector2.ZERO
	_order_direction = Vector2.ZERO
	_disable_meander()

	if nav_agent and agent:
		nav_agent.target_position = agent.global_position

	return true


func command_player_direction(dir: Vector2, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.PLAYER_DIRECTION
	_order_direction = dir
	_order_target_node = null
	_order_target_pos = Vector2.ZERO
	_order_raw_velocity = Vector2.ZERO
	_disable_meander()

	if nav_agent and agent:
		nav_agent.target_position = agent.global_position
		
	return true


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

	if nav_agent and agent:
		nav_agent.target_position = agent.global_position


# --- Pathfinding Logic ---

func _process_pathfinding(my_pos: Vector2, speed_limit: float, delta: float) -> void:
	if not nav_agent or speed_limit <= 0.0:
		move_with_velocity(Vector2.ZERO, delta)
		return

	# --- stuck detection ---
	# Bolt: Use squared distance to avoid sqrt every frame
	var progress_sq := my_pos.distance_squared_to(_last_my_pos)
	# _last_my_pos updated only when we move enough (see below)

	var min_dist_frame := min_progress_per_sec * delta
	if progress_sq < (min_dist_frame * min_dist_frame):
		_stuck_accum += delta
	else:
		_stuck_accum = 0.0
		_last_my_pos = my_pos

	if _stuck_accum >= stuck_time:
		_stuck_accum = 0.0
		# push_warning("AgentMovement: Agent stuck at " + str(my_pos))
		if _order_type == OrderType.MEANDER:
			_pick_new_patrol_point()
		else:
			_refresh_target_and_repath(true)


	if nav_agent.is_navigation_finished():
		# Handled by signal _on_nav_finished
		return

	# --- compute desired velocity toward next path point ---
	var next_pos := nav_agent.get_next_path_position()
	var to_next := next_pos - my_pos
	if to_next.length_squared() < 0.0001:
		move_with_velocity(Vector2.ZERO, delta)
		return

	var desired := to_next.normalized() * speed_limit

	# Optional slowing near final target
	# Bolt: Check squared distance first to avoid sqrt when outside radius
	if slow_radius > 0.0:
		var dist_sq := my_pos.distance_squared_to(nav_agent.target_position)
		if dist_sq < (slow_radius * slow_radius):
			var dist_to_target := sqrt(dist_sq)
			var t: float = clamp(dist_to_target / slow_radius, 0.0, 1.0)
			desired *= t

	nav_agent.max_speed = speed_limit
	nav_agent.set_velocity(desired)


func _on_repath_tick() -> void:
	_refresh_target_and_repath(false)


func _refresh_target_and_repath(force: bool) -> void:
	if not nav_agent:
		return

	# If chasing, update chase position (or clear if target died)
	if _order_type == OrderType.CHASE_NODE:
		if is_instance_valid(_order_target_node):
			_order_target_pos = _order_target_node.global_position
			_set_target_pos(_order_target_pos)
		else:
			# Target lost/died
			clear_movement_order(_order_priority)
			return

	# If meandering and we don't currently have a meaningful target (e.g. cleared), pick one
	if _order_type == OrderType.MEANDER and nav_agent.is_navigation_finished():
		return

	# Only repath if moved enough (unless forced)
	# Bolt: Use squared distance check
	if force or _order_target_pos.distance_squared_to(_last_target_pos) >= (target_repath_distance * target_repath_distance):
		_set_target_pos(_order_target_pos)


func _set_target_pos(pos: Vector2) -> void:
	_target_pos = pos
	_last_target_pos = pos
	if nav_agent:
		nav_agent.target_position = pos
