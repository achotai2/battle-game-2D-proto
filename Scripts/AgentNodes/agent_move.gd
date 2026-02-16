extends Node
class_name AgentMovement

signal move_to_pos_finished(agent: Node2D)

# --- CONFIGURATION ---
@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0
@export var can_meander: bool = true
@export var loiter_duration: float = 2.0

# --- ASSIGNMENTS (STRICT TYPED) ---
# [OPTIMIZATION] strict typing for direct memory access
@export var agent: CharacterBody3D = null
@export var animation: AgentAnimate = null
@export var nav_agent: NavigationAgent3D

# --- TUNING ---
@export_range(0.05, 20.0, 0.05) var repath_interval: float = 1.0
@export_range(1.0, 200.0, 1.0) var target_repath_distance: float = 250.0
@export_range(0.1, 5.0, 0.1) var stuck_check_interval: float = 4.0 
@export_range(0.0, 200.0, 1.0) var min_progress_per_sec: float = 10.0
@export_range(0.0, 200.0, 1.0) var slow_radius: float = 0.0
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

# --- PATROL ---
@export var assigned_castle: Node2D
@export_range(0.0, 2000.0, 10.0) var patrol_radius: float = 500.0
@export_range(0.0, 200.0, 1.0) var patrol_arrival_radius: float = 50.0
@export_range(0.0, 10.0, 0.1) var patrol_pause_seconds: float = 0.5
@export_range(1, 20, 1) var patrol_pick_attempts: int = 8

enum OrderType { NONE, MEANDER, MOVE_TO_POS, CHASE_NODE, RAW_VELOCITY, PLAYER_DIRECTION, FROZEN }

# --- STATE ---
var _order_type: OrderType = OrderType.NONE
var _order_priority: int = -1
var _target_pos: Vector3 = Vector3.ZERO
var _last_target_pos: Vector3 = Vector3.ZERO

# [OPTIMIZATION] Cache the current speed cap to avoid function calls in the loop
var _current_speed_cap: float = 0.0

# Stuck detection state
var _last_stuck_pos: Vector3 = Vector3.ZERO

# Optimization: Cached Velocity
var _cached_desired_vel: Vector3 = Vector3.ZERO
var _current_velocity: Vector3 = Vector3.ZERO
var _last_anim_velocity: Vector3 = Vector3(INF, 0, INF)
const ANIM_JITTER_THRESHOLD_SQ: float = 4.0 

# Optimization: Staggered Updates
var _frame_offset: int = 0
const PATH_UPDATE_INTERVAL: int = 4 

# Temporary command storage
var _order_target_node: Node2D = null
var _order_direction: Vector3 = Vector3.ZERO

# Timers
var _repath_timer: Timer
var _patrol_pause_timer: Timer
var _loiter_timer: Timer

func _ready() -> void:
	if not nav_agent:
		set_physics_process(false)
		return

	_frame_offset = randi() % PATH_UPDATE_INTERVAL
	
	# Initial Speed Cap
	_current_speed_cap = max_speed

	# Ensure we start with avoidance OFF if you want performance
	nav_agent.avoidance_enabled = false
	nav_agent.target_desired_distance = patrol_arrival_radius
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_nav_finished)

	_repath_timer = Timer.new()
	_repath_timer.wait_time = repath_interval
	_repath_timer.timeout.connect(_on_repath_timer_tick)
	_repath_timer.autostart = true
	add_child(_repath_timer)
	_repath_timer.start(randf() * repath_interval)

	_patrol_pause_timer = Timer.new()
	_patrol_pause_timer.one_shot = true
	_patrol_pause_timer.timeout.connect(_on_patrol_pause_timeout)
	add_child(_patrol_pause_timer)

	_loiter_timer = Timer.new()
	_loiter_timer.one_shot = true
	_loiter_timer.timeout.connect(_on_loiter_timeout)
	add_child(_loiter_timer)
	
	if agent: _last_stuck_pos = agent.global_position

# --- MAIN LOOP ---

func tick(delta: float) -> void:
	# [FIX] Check for auto-meander FIRST.
	# If we are supposed to meander, start immediately so we don't get put to sleep below.
	if _order_type == OrderType.NONE and can_meander:
		if _loiter_timer.is_stopped():
			_start_self_meander()
		else:
			# Loitering (smoking a cigarette)
			pass

	# [OPTIMIZATION] Sleep Check
	# Now this only triggers if we are NONE (and didn't start meandering) or FROZEN
	if (_order_type == OrderType.NONE or _order_type == OrderType.FROZEN) and _current_velocity.is_zero_approx():
		if animation: _update_visuals()
		return
	
	if _order_type == OrderType.FROZEN:
		move_with_velocity(Vector3.ZERO, delta)
		return

	# ... (Rest of logic remains the same) ...

	match _order_type:
		OrderType.MEANDER, OrderType.MOVE_TO_POS, OrderType.CHASE_NODE:
			if agent:
				_process_pathfinding(agent.global_position, delta)
			
		OrderType.PLAYER_DIRECTION:
			move_in_direction(_order_direction, delta)

		OrderType.RAW_VELOCITY:
			move_with_velocity(Vector3.ZERO, delta)

		OrderType.NONE:
			move_with_velocity(Vector3.ZERO, delta)

	_update_visuals()
	

# --- PATHFINDING CORE ---

func _process_pathfinding(my_pos: Vector3, delta: float) -> void:
	if nav_agent.is_navigation_finished():
		# If we return early without this, the unit keeps the last known velocity 
		# and slides off the map (Cruise Control bug).
		move_with_velocity(Vector3.ZERO, delta)
		return
		
	# [OPTIMIZATION] Throttled Path Calculation
	if (Engine.get_physics_frames() + _frame_offset) % PATH_UPDATE_INTERVAL == 0:
		var next_pos = nav_agent.get_next_path_position()
		var to_next = next_pos - my_pos
		to_next.y = 0 # Force movement on XZ plane
		
		if to_next.length_squared() > 1.0:
			# Use cached speed cap
			var desired = to_next.normalized() * _current_speed_cap
			
			if slow_radius > 0.0:
				var dist_sq = my_pos.distance_squared_to(nav_agent.target_position)
				if dist_sq < (slow_radius * slow_radius):
					desired *= (sqrt(dist_sq) / slow_radius)
			
			_cached_desired_vel = desired
		else:
			_cached_desired_vel = Vector3.ZERO

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(_cached_desired_vel)
	else:
		move_with_velocity(_cached_desired_vel, delta)

# --- VELOCITY & MOVEMENT (HOT PATH) ---

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if accel == 0.0:
		move_with_velocity(safe_velocity, 0.0)
	else:
		move_with_velocity(safe_velocity, get_physics_process_delta_time())

func move_with_velocity(desired_velocity: Vector3, delta: float) -> void:
	if _order_type == OrderType.FROZEN:
		_current_velocity = Vector3.ZERO
		# [OPTIMIZATION] Only update agent if not already stopped
		if agent and not agent.velocity.is_zero_approx():
			agent.velocity = Vector3.ZERO
		return

	# [OPTIMIZATION] Use cached variable, not a function call
	var v = desired_velocity.limit_length(_current_speed_cap)

	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	if agent:
		# [OPTIMIZATION] Redundancy check. 
		# Don't wake up Physics Server if velocity hasn't changed.
		if not agent.velocity.is_equal_approx(_current_velocity):
			agent.velocity = _current_velocity

# --- VISUALS ---

func _update_visuals() -> void:
	if not animation: return
	
	if _current_velocity.distance_squared_to(_last_anim_velocity) > ANIM_JITTER_THRESHOLD_SQ:
		animation.agent_moved(_current_velocity)
		_last_anim_velocity = _current_velocity
	elif _current_velocity.is_zero_approx() and not _last_anim_velocity.is_zero_approx():
		animation.agent_moved(Vector3.ZERO)
		_last_anim_velocity = Vector3.ZERO

# --- STUCK DETECTION ---

func _on_repath_timer_tick() -> void:
	if not agent: return
	
	# [OPTIMIZATION] 1. If we aren't trying to move, stop processing.
	# This effectively "sleeps" the timer for stationary units.
	if _order_type == OrderType.NONE or _order_type == OrderType.FROZEN:
		_last_stuck_pos = agent.global_position
		return

	# [OPTIMIZATION] 2. If we have arrived, we aren't "stuck", we are done.
	# This prevents arrived units from spamming the NavigationServer.
	if nav_agent.is_navigation_finished():
		_last_stuck_pos = agent.global_position
		# Note: We don't return here if Chasing, because target might move.
		# But we skip the stuck check below.
	
	# --- CHASE LOGIC ---
	if _order_type == OrderType.CHASE_NODE:
		if is_instance_valid(_order_target_node):
			var target_pos = _order_target_node.global_position
			if target_pos.distance_squared_to(_last_target_pos) > (target_repath_distance * target_repath_distance):
				_set_target_pos(target_pos)
		else:
			clear_movement_order(_order_priority)
			return

	# --- STUCK DETECTION ---
	# Only run stuck detection if we haven't arrived yet
	if not nav_agent.is_navigation_finished():
		var dist_sq = agent.global_position.distance_squared_to(_last_stuck_pos)
		var min_dist = min_progress_per_sec * repath_interval
		
		if dist_sq < (min_dist * min_dist):
			# We are stuck
			if _order_type == OrderType.MEANDER:
				_pick_new_patrol_point()
			elif _order_type == OrderType.MOVE_TO_POS or _order_type == OrderType.CHASE_NODE:
				# Force a full path re-query
				if nav_agent.target_position != Vector3.ZERO:
					nav_agent.target_position = nav_agent.target_position
	
	_last_stuck_pos = agent.global_position
	

# --- COMMANDS ---

# Helper to update cached speed when state changes
func _update_speed_cap() -> void:
	if _order_type == OrderType.MEANDER:
		_current_speed_cap = meander_speed
	else:
		_current_speed_cap = max_speed

func command_move_to_position(pos: Vector3, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_cancel_anim_actions()
	_order_type = OrderType.MOVE_TO_POS
	_update_speed_cap() # Update Cache
	_set_target_pos(pos)
	return true

func command_player_direction(dir: Vector3, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_cancel_anim_actions()
	_order_type = OrderType.PLAYER_DIRECTION
	_order_direction = dir
	_order_target_node = null
	_target_pos = Vector3.ZERO
	_cached_desired_vel = Vector3.ZERO
	_update_speed_cap() # Update Cache
	return true

func command_chase_target(node: Node2D, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_cancel_anim_actions()
	_order_type = OrderType.CHASE_NODE
	_order_target_node = node
	_update_speed_cap() # Update Cache
	_on_repath_timer_tick()
	return true

func command_start_interaction(priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_order_type = OrderType.FROZEN
	# Speed cap irrelevant for frozen, but good practice
	if animation: animation.play_work()
	return true

func command_start_work(priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_order_type = OrderType.FROZEN
	if animation: animation.play_work()
	return true

func command_start_attack(target: Node2D, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_order_type = OrderType.FROZEN
	if animation: animation.play_attack(target)
	return true

func _accept_order(priority: int) -> bool:
	if priority < _order_priority: return false
	_order_priority = priority
	return true

func _start_self_meander() -> void:
	if not is_instance_valid(assigned_castle):
		can_meander = false; return
	_cancel_anim_actions()
	_order_type = OrderType.MEANDER
	_order_priority = 0
	_update_speed_cap() # Update Cache
	_pick_new_patrol_point()

func move_in_direction(direction: Vector3, delta: float) -> void:
	move_with_velocity(direction.normalized() * max_speed, delta)

func clear_movement_order(priority: int = 5) -> void:
	if priority < _order_priority: return
	_cancel_anim_actions()
	_order_type = OrderType.NONE
	_order_priority = -1
	_update_speed_cap()

	if can_meander and loiter_duration > 0.0:
		_loiter_timer.start(loiter_duration)

# --- HELPERS ---

func _cancel_anim_actions() -> void:
	if animation: animation.cancel_action_state()

func _set_target_pos(pos: Vector3) -> void:
	_target_pos = pos
	_last_target_pos = pos
	if nav_agent: nav_agent.target_position = pos

func _on_nav_finished() -> void:
	if _order_type == OrderType.MOVE_TO_POS:
		_order_type = OrderType.NONE
		move_to_pos_finished.emit(get_parent())

		# If no new order came in from the signal (e.g. Work), start loitering
		if _order_type == OrderType.NONE and can_meander and loiter_duration > 0.0:
			_loiter_timer.start(loiter_duration)

	elif _order_type == OrderType.MEANDER:
		if patrol_pause_seconds > 0.0:
			_patrol_pause_timer.start(patrol_pause_seconds)
		else:
			_pick_new_patrol_point()

func _on_patrol_pause_timeout() -> void:
	if _order_type == OrderType.MEANDER:
		_pick_new_patrol_point()

func _on_loiter_timeout() -> void:
	if _order_type == OrderType.NONE and can_meander:
		_start_self_meander()

func _pick_new_patrol_point() -> void:
	if not is_instance_valid(assigned_castle):
		if agent: _set_target_pos(agent.global_position)
		return
	var center = assigned_castle.global_position
	var angle = randf() * TAU
	var r = sqrt(randf()) * patrol_radius
	var candidate = center + Vector3(cos(angle), 0, sin(angle)) * r
	_set_target_pos(candidate)

# --- COMPATIBILITY BLOCK ---
func set_animation(anim: AgentAnimate) -> void: animation = anim
func is_frozen() -> bool: return _order_type == OrderType.FROZEN
func no_order_check() -> bool: return _order_type == OrderType.NONE
func _disable_meander() -> void: pass
func force_repath() -> void: _on_repath_timer_tick()
func set_my_agent(owner_agent: CharacterBody3D) -> void: agent = owner_agent
