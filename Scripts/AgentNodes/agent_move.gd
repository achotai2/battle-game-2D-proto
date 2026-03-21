extends Node
class_name AgentMovement

signal move_to_pos_finished(agent: AgentBase)
signal stuck(agent: AgentBase)

# --- CONFIGURATION ---
@export_range(0, 500, 0.0) var max_speed: float = 5.0

# --- ASSIGNMENTS (Injected by AgentBase!) ---
var agent: AgentBase = null
var animation: Node = null 
var nav_agent: NavigationAgent3D = null

# --- TUNING ---
@export_range(0.05, 20.0, 0.05) var repath_interval: float = 1.0
@export_range(1.0, 200.0, 1.0) var target_repath_distance: float = 2.0
@export_range(0.0, 200.0, 1.0) var min_progress_per_sec: float = 0.5
@export_range(0.0, 200.0, 1.0) var slow_radius: float = 0.0
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

enum Mode { VELOCITY, PATHFINDING }
var _mode: Mode = Mode.VELOCITY

var _desired_velocity: Vector3 = Vector3.ZERO
var _current_velocity: Vector3 = Vector3.ZERO
var _last_anim_velocity: Vector3 = Vector3(INF, 0, INF)
const ANIM_JITTER_THRESHOLD_SQ: float = 0.01 

# Pathfinding State
var _last_stuck_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _frame_offset: int = 0
const PATH_UPDATE_INTERVAL: int = 4 


func _ready() -> void:
	pass

func deactivate() -> void:
	pass

func activate() -> void:
	# Sleep immediately. We wait for AgentBase to wake us up.
	set_physics_process(false)


# --- TOP-DOWN INJECTION ---
func setup(owner_agent: AgentBase, anim_node: Node, nav_node: NavigationAgent3D) -> void:
	agent = owner_agent
	animation = anim_node
	nav_agent = nav_node
	
	if is_instance_valid(agent):
		_last_stuck_pos = agent.global_position

	# Handle Navigation Setup safely
	if is_instance_valid(nav_agent):
		_frame_offset = randi() % PATH_UPDATE_INTERVAL
		nav_agent.avoidance_enabled = false
		nav_agent.target_desired_distance = 1.0
		
		if not nav_agent.velocity_computed.is_connected(_on_velocity_computed):
			nav_agent.velocity_computed.connect(_on_velocity_computed)
		if not nav_agent.navigation_finished.is_connected(_on_nav_finished):
			nav_agent.navigation_finished.connect(_on_nav_finished)
			
		# Wake up the physics process now that we have our brain!
		set_physics_process(true)
	else:
		set_physics_process(false)


func tick(delta: float) -> void:
	if _mode == Mode.VELOCITY:
		move_with_velocity(_desired_velocity, delta)
	elif _mode == Mode.PATHFINDING:
		_process_pathfinding(delta)

	_update_visuals()


func _process_pathfinding(delta: float) -> void:
	if not agent: return
	if nav_agent.is_navigation_finished():
		move_with_velocity(Vector3.ZERO, delta)
		return
		
	# Stuck Detection
	_stuck_timer += delta
	if _stuck_timer >= repath_interval:
		_stuck_timer = 0.0
		var dist_sq = agent.global_position.distance_squared_to(_last_stuck_pos)
		var min_dist = min_progress_per_sec * repath_interval
		if dist_sq < (min_dist * min_dist):
			move_with_velocity(Vector3.ZERO, delta)
			stuck.emit(agent)
			return 

		_last_stuck_pos = agent.global_position

	# Path Following
	if (Engine.get_physics_frames() + _frame_offset) % PATH_UPDATE_INTERVAL == 0:
		var next_pos = nav_agent.get_next_path_position()
		var to_next = next_pos - agent.global_position
		to_next.y = 0
		
		var desired = Vector3.ZERO
		if to_next.length_squared() > 0.1:
			desired = to_next.normalized() * max_speed
			
			if slow_radius > 0.0:
				var dist_sq = agent.global_position.distance_squared_to(nav_agent.target_position)
				if dist_sq < (slow_radius * slow_radius):
					desired *= (sqrt(dist_sq) / slow_radius)

		_desired_velocity = desired

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(_desired_velocity)
	else:
		move_with_velocity(_desired_velocity, delta)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if accel == 0.0:
		move_with_velocity(safe_velocity, 0.0)
	else:
		move_with_velocity(safe_velocity, get_physics_process_delta_time())


func move_with_velocity(vel: Vector3, delta: float) -> void:
	var v = vel.limit_length(max_speed)

	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	if agent:
		if not agent.velocity.is_equal_approx(_current_velocity):
			agent.velocity = _current_velocity


func _update_visuals() -> void:
	if not is_instance_valid(animation): return
	
	if _current_velocity.distance_squared_to(_last_anim_velocity) > ANIM_JITTER_THRESHOLD_SQ:
		if animation.has_method("play_walk"):
			animation.play_walk(_current_velocity)
		_last_anim_velocity = _current_velocity
		
	elif _current_velocity.is_zero_approx() and not _last_anim_velocity.is_zero_approx():
		if animation.has_method("play_idle"):
			animation.play_idle()
		_last_anim_velocity = Vector3.ZERO


func _on_nav_finished() -> void:
	if _mode == Mode.PATHFINDING:
		move_to_pos_finished.emit(agent)


# --- COMMANDS --- 

func move_to_position(pos: Vector3) -> void:
	if _mode == Mode.PATHFINDING and nav_agent.target_position.distance_squared_to(pos) < 0.1:
		return

	_mode = Mode.PATHFINDING
	nav_agent.target_position = pos
	_stuck_timer = 0.0
	if agent: _last_stuck_pos = agent.global_position

	if is_instance_valid(animation) and animation.has_method("cancel_action_state"): 
		animation.cancel_action_state()


func move_in_direction(dir: Vector3) -> void:
	var target_vel = dir * max_speed
	
	if _mode == Mode.VELOCITY and _desired_velocity.is_equal_approx(target_vel):
		return
		
	_mode = Mode.VELOCITY
	_desired_velocity = target_vel
	
	if is_instance_valid(animation) and animation.has_method("cancel_action_state"): 
		animation.cancel_action_state()
		
		
func stop() -> void:
	move_in_direction(Vector3.ZERO)


func clear_movement() -> void:
	stop()


# --- COMPATIBILITY ---
func is_navigation_finished() -> bool: 
	if is_instance_valid(nav_agent):
		return nav_agent.is_navigation_finished()
	return true
