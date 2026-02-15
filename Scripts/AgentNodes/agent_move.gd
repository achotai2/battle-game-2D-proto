extends Node
class_name AgentMovement

signal move_to_pos_finished(agent: Node2D)

# --- CONFIGURATION ---
@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0
@export var can_meander: bool = true

# --- ASSIGNMENTS ---
@export var agent: Node2D = null
@export var animation: AgentAnimate = null
@export var nav_agent: NavigationAgent2D

# --- TUNING ---
@export_range(0.05, 20.0, 0.05) var repath_interval: float = 1.0
@export_range(1.0, 200.0, 1.0) var target_repath_distance: float = 250.0
@export_range(0.1, 5.0, 0.1) var stuck_check_interval: float = 1.0 
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
var _target_pos: Vector2 = Vector2.ZERO
var _last_target_pos: Vector2 = Vector2.ZERO # For repath distance check

# Stuck detection state
var _last_stuck_pos: Vector2 = Vector2.ZERO

# Optimization: Cached Velocity
var _cached_desired_vel: Vector2 = Vector2.ZERO
var _current_velocity: Vector2 = Vector2.ZERO
var _last_anim_velocity: Vector2 = Vector2(INF, INF)
const ANIM_JITTER_THRESHOLD_SQ: float = 4.0 

# Optimization: Staggered Updates
var _frame_offset: int = 0
const PATH_UPDATE_INTERVAL: int = 4 # Update path logic every 4 frames

# Temporary command storage
var _order_target_node: Node2D = null
var _order_direction: Vector2 = Vector2.ZERO

# Timers
var _repath_timer: Timer
var _patrol_pause_timer: Timer

func _ready() -> void:
	if not nav_agent:
		push_warning("AgentMovement: nav_agent is not assigned.")
		set_physics_process(false) # Disable script if invalid
		return

	# Randomize frame offset so units don't all calculate on the same frame
	_frame_offset = randi() % PATH_UPDATE_INTERVAL

	nav_agent.avoidance_enabled = true
	nav_agent.target_desired_distance = patrol_arrival_radius
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_nav_finished)

	_repath_timer = Timer.new()
	_repath_timer.wait_time = repath_interval
	_repath_timer.timeout.connect(_on_repath_timer_tick)
	_repath_timer.autostart = true
	add_child(_repath_timer)
	
	# Stagger repath timer
	_repath_timer.start(randf() * repath_interval)

	_patrol_pause_timer = Timer.new()
	_patrol_pause_timer.one_shot = true
	_patrol_pause_timer.timeout.connect(_on_patrol_pause_timeout)
	add_child(_patrol_pause_timer)
	
	# Initialize stuck check pos
	if agent: _last_stuck_pos = agent.global_position

# --- MAIN LOOP ---

func tick(delta: float) -> void:
	if _order_type == OrderType.FROZEN:
		move_with_velocity(Vector2.ZERO, delta)
		return

	# Auto-start meander if idle
	if _order_type == OrderType.NONE and can_meander:
		_start_self_meander()

	# --- 1. LOGIC ---
	match _order_type:
		OrderType.MEANDER, OrderType.MOVE_TO_POS, OrderType.CHASE_NODE:
			if agent:
				_process_pathfinding(agent.global_position, delta)
			
		OrderType.PLAYER_DIRECTION:
			move_in_direction(_order_direction, delta)

		OrderType.RAW_VELOCITY:
			# Raw velocity usually comes from _order_direction or temp var
			# But here we just assume the command set the velocity elsewhere or we stop
			move_with_velocity(Vector2.ZERO, delta) 

		OrderType.NONE:
			move_with_velocity(Vector2.ZERO, delta)

	# --- 2. VISUALS ---
	_update_visuals()

# --- PATHFINDING CORE (OPTIMIZED) ---

func _process_pathfinding(my_pos: Vector2, delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return

	# [OPTIMIZATION] Throttled Path Calculation
	# Only calculate the geometry direction every X frames.
	# The rest of the time, use the cached vector.
	if (Engine.get_physics_frames() + _frame_offset) % PATH_UPDATE_INTERVAL == 0:
		
		var next_pos = nav_agent.get_next_path_position()
		var to_next = next_pos - my_pos
		
		# Only update if meaningful distance
		if to_next.length_squared() > 1.0:
			var desired = to_next.normalized() * return_speed()
			
			# Arrival slowing
			if slow_radius > 0.0:
				var dist_sq = my_pos.distance_squared_to(nav_agent.target_position)
				if dist_sq < (slow_radius * slow_radius):
					desired *= (sqrt(dist_sq) / slow_radius)
			
			_cached_desired_vel = desired
		else:
			_cached_desired_vel = Vector2.ZERO

	# [REQUIRED] RVO Step - Must happen every frame to keep simulation stable
	nav_agent.set_velocity(_cached_desired_vel)


# --- STUCK DETECTION & REPATHING (Timer Based) ---

func _on_repath_timer_tick() -> void:
	if not agent: return
	
	# 1. Chase Logic
	if _order_type == OrderType.CHASE_NODE:
		if is_instance_valid(_order_target_node):
			var target_pos = _order_target_node.global_position
			# Only repath if target moved significantly
			if target_pos.distance_squared_to(_last_target_pos) > (target_repath_distance * target_repath_distance):
				_set_target_pos(target_pos)
		else:
			clear_movement_order(_order_priority)
			return

	# 2. Stuck Detection (Moved out of tick!)
	# We check if we have moved less than X pixels over the last Y seconds
	var dist_sq = agent.global_position.distance_squared_to(_last_stuck_pos)
	var min_dist = min_progress_per_sec * repath_interval
	
	if dist_sq < (min_dist * min_dist):
		# We are stuck
		if _order_type == OrderType.MEANDER:
			_pick_new_patrol_point()
		elif _order_type == OrderType.MOVE_TO_POS or _order_type == OrderType.CHASE_NODE:
			# Force a full path re-query
			if nav_agent.target_position != Vector2.ZERO:
				nav_agent.target_position = nav_agent.target_position
	
	_last_stuck_pos = agent.global_position


# --- VELOCITY & MOVEMENT ---

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if accel == 0.0:
		move_with_velocity(safe_velocity, 0.0)
	else:
		move_with_velocity(safe_velocity, get_physics_process_delta_time())

func move_with_velocity(desired_velocity: Vector2, delta: float) -> void:
	if _order_type == OrderType.FROZEN:
		_current_velocity = Vector2.ZERO
		if agent: agent.velocity = Vector2.ZERO
		return

	var speed_cap = return_speed()
	
	# Optimized Limit
	var v = desired_velocity.limit_length(speed_cap)

	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	if agent:
		agent.velocity = _current_velocity


func _update_visuals() -> void:
	if not animation: return
	
	# Jitter threshold check
	if _current_velocity.distance_squared_to(_last_anim_velocity) > ANIM_JITTER_THRESHOLD_SQ:
		animation.agent_moved(_current_velocity)
		_last_anim_velocity = _current_velocity
	elif _current_velocity.is_zero_approx() and not _last_anim_velocity.is_zero_approx():
		animation.agent_moved(Vector2.ZERO)
		_last_anim_velocity = Vector2.ZERO

# --- HELPERS ---

func return_speed() -> float:
	if _order_type == OrderType.MEANDER: return meander_speed
	return max_speed

func _set_target_pos(pos: Vector2) -> void:
	_target_pos = pos
	_last_target_pos = pos
	if nav_agent: nav_agent.target_position = pos

func _on_nav_finished() -> void:
	if _order_type == OrderType.MOVE_TO_POS:
		_order_type = OrderType.NONE
		move_to_pos_finished.emit(get_parent())
	elif _order_type == OrderType.MEANDER:
		if patrol_pause_seconds > 0.0:
			_patrol_pause_timer.start(patrol_pause_seconds)
		else:
			_pick_new_patrol_point()

func _on_patrol_pause_timeout() -> void:
	if _order_type == OrderType.MEANDER:
		_pick_new_patrol_point()

func _pick_new_patrol_point() -> void:
	if not is_instance_valid(assigned_castle):
		if agent: _set_target_pos(agent.global_position)
		return

	var center = assigned_castle.global_position
	# Simplified random point logic
	var angle = randf() * TAU
	var r = sqrt(randf()) * patrol_radius
	var candidate = center + Vector2(cos(angle), sin(angle)) * r
	
	# We don't need to check map_get_closest_point every time for meandering,
	# the NavAgent handles unreachable points gracefully usually.
	
	_set_target_pos(candidate)

# --- COMMANDS (Simplified) ---

func command_move_to_position(pos: Vector2, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_order_type = OrderType.MOVE_TO_POS
	_set_target_pos(pos)
	return true


func command_player_direction(dir: Vector2, priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.PLAYER_DIRECTION
	_order_direction = dir
	
	# Clear other targets to avoid confusion
	_order_target_node = null
	_target_pos = Vector2.ZERO 
	
	# Reset caching so we respond instantly to input
	_cached_desired_vel = Vector2.ZERO 
	
	return true



func command_chase_target(node: Node2D, priority: int = 5) -> bool:
	if not _accept_order(priority): return false
	_order_type = OrderType.CHASE_NODE
	_order_target_node = node
	_on_repath_timer_tick() # Initial path
	return true


func command_start_interaction(priority: int = 5) -> bool:
	if not _accept_order(priority):
		return false

	_order_type = OrderType.FROZEN

	if animation:
		animation.play_work()

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
	_order_type = OrderType.MEANDER
	_order_priority = 0
	_pick_new_patrol_point()

func move_in_direction(direction: Vector2, delta: float) -> void:
	move_with_velocity(direction.normalized() * max_speed, delta)

func clear_movement_order(priority: int = 5) -> void:
	if priority < _order_priority: return
	_order_type = OrderType.NONE
	_order_priority = -1
