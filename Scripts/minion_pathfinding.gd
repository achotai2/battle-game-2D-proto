extends Node
class_name MinionPathfinding

signal desired_velocity(v: Vector2)
signal nav_finished

@export var nav_agent: NavigationAgent2D

# --- Repath tuning ---
@export_range(0.05, 2.0, 0.05) var repath_interval: float = 2.0
@export_range(1.0, 200.0, 1.0) var target_repath_distance: float = 250.0

# --- Stuck detection ---
@export_range(0.1, 2.0, 0.05) var stuck_time: float = 1.0
@export_range(0.0, 200.0, 1.0) var min_progress_per_sec: float = 8.0

# --- Arrival ---
@export_range(0.0, 200.0, 1.0) var slow_radius: float = 0.0

# --- Patrol / meander ---
@export var assigned_castle: Node2D
@export_range(0.0, 2000.0, 10.0) var patrol_radius: float = 500.0
@export_range(0.0, 200.0, 1.0) var patrol_arrival_radius: float = 24.0
@export_range(0.0, 10.0, 0.1) var patrol_pause_seconds: float = 0.5
@export_range(1, 20, 1) var patrol_pick_attempts: int = 8

var meander_enabled: bool = false

# Target mode
enum Mode { NONE, MOVE_TO_POS, CHASE_NODE, PATROL }
var _mode: Mode = Mode.NONE

var _target_node: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _last_target_pos: Vector2 = Vector2.ZERO

# timers / tracking
var _repath_timer: Timer
var _patrol_pause_timer: Timer
var _last_my_pos: Vector2 = Vector2.ZERO
var _stuck_accum: float = 0.0


func _ready() -> void:
	if not is_instance_valid(nav_agent):
		push_warning("MinionPathfinding: nav_agent is not assigned.")
		return

	nav_agent.avoidance_enabled = true
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
	_patrol_pause_timer.timeout.connect(_on_patrol_pause_finished)
	add_child(_patrol_pause_timer)


# -------------------------
# Public API
# -------------------------

func set_meander(enable: bool) -> void:
	if enable == meander_enabled:
		return

	if enable:
		meander_enabled = true
		start_patrol()
	else:
		meander_enabled = false
		# Only clear if we were patrolling; otherwise leave current mode alone
		if _mode == Mode.PATROL:
			clear_target()


func set_move_target_position(pos: Vector2) -> void:
	_mode = Mode.MOVE_TO_POS
	_target_node = null
	_set_target_pos(pos)


func set_chase_target(node: Node2D) -> void:
	_mode = Mode.CHASE_NODE
	_target_node = node
	if is_instance_valid(_target_node):
		_set_target_pos(_target_node.global_position)
	else:
		clear_target()


func start_patrol() -> void:
	_mode = Mode.PATROL
	_target_node = null
	_pick_new_patrol_point(true)


func clear_target() -> void:
	_mode = Mode.NONE
	_target_node = null
	_stuck_accum = 0.0
	_patrol_pause_timer.stop()
	_send_desired_velocity(Vector2.ZERO)


# Call from Agent._physics_process(delta)
func tick(my_pos: Vector2, max_speed: float, delta: float) -> void:
	if not is_instance_valid(nav_agent) or max_speed <= 0.0:
		_send_desired_velocity(Vector2.ZERO)
		return

	# If meander enabled, patrol mode should be active unless something else overrides it.
	# (You can choose your own policy; this is the simplest.)
	if meander_enabled and _mode == Mode.NONE:
		start_patrol()

	if _mode == Mode.NONE:
		_send_desired_velocity(Vector2.ZERO)
		return

	# --- stuck detection ---
	# Bolt: Use squared distance to avoid sqrt every frame
	var progress_sq := my_pos.distance_squared_to(_last_my_pos)
	_last_my_pos = my_pos

	var min_dist_frame := min_progress_per_sec * delta
	if progress_sq < (min_dist_frame * min_dist_frame):
		_stuck_accum += delta
	else:
		_stuck_accum = 0.0

	if _stuck_accum >= stuck_time:
		_stuck_accum = 0.0
		_refresh_target_and_repath(true)

	# --- finished? ---
	if _mode == Mode.PATROL and _is_patrol_target_reached(my_pos):
		_send_desired_velocity(Vector2.ZERO)
		if not _patrol_pause_timer.is_stopped():
			return
		if patrol_pause_seconds > 0.0:
			_patrol_pause_timer.start(patrol_pause_seconds)
		else:
			_pick_new_patrol_point(true)
		return

	if nav_agent.is_navigation_finished():
		_send_desired_velocity(Vector2.ZERO)
		# Patrol: upon arrival, pause then pick a new point
		if _mode == Mode.PATROL and not _patrol_pause_timer.is_stopped():
			return
		if _mode == Mode.PATROL:
			if patrol_pause_seconds > 0.0:
				_patrol_pause_timer.start(patrol_pause_seconds)
			else:
				_pick_new_patrol_point(true)
		return

	# --- compute desired velocity toward next path point ---
	var next_pos := nav_agent.get_next_path_position()
	var to_next := next_pos - my_pos
	if to_next.length_squared() < 0.0001:
		_send_desired_velocity(Vector2.ZERO)
		return

	var desired := to_next.normalized() * max_speed

	# Optional slowing near final target
	# Bolt: Check squared distance first to avoid sqrt when outside radius
	if slow_radius > 0.0:
		var dist_sq := my_pos.distance_squared_to(nav_agent.target_position)
		if dist_sq < (slow_radius * slow_radius):
			var dist_to_target := sqrt(dist_sq)
			var t: float = clamp(dist_to_target / slow_radius, 0.0, 1.0)
			desired *= t

	nav_agent.max_speed = max_speed
	nav_agent.set_velocity(desired)


# -------------------------
# Internals
# -------------------------

func _on_repath_tick() -> void:
	_refresh_target_and_repath(false)


func _refresh_target_and_repath(force: bool) -> void:
	if _mode == Mode.NONE or not is_instance_valid(nav_agent):
		return

	# If chasing, update chase position (or clear if target died)
	if _mode == Mode.CHASE_NODE:
		if is_instance_valid(_target_node):
			_target_pos = _target_node.global_position
		else:
			clear_target()
			return

	# If patrolling and we don't currently have a meaningful target (e.g. cleared), pick one
	if _mode == Mode.PATROL and nav_agent.is_navigation_finished():
		return

	# Only repath if moved enough (unless forced)
	# Bolt: Use squared distance check
	if force or _target_pos.distance_squared_to(_last_target_pos) >= (target_repath_distance * target_repath_distance):
		_last_target_pos = _target_pos
		nav_agent.target_position = _target_pos


func _set_target_pos(pos: Vector2) -> void:
	_target_pos = pos
	_last_target_pos = pos
	if is_instance_valid(nav_agent):
		nav_agent.target_position = pos


func _on_patrol_pause_finished() -> void:
	if _mode == Mode.PATROL:
		_pick_new_patrol_point(true)


func _pick_new_patrol_point(force: bool) -> void:
	if _mode != Mode.PATROL:
		return
	if not is_instance_valid(assigned_castle):
		# No castle -> can't patrol; just stop
		clear_target()
		return

	var center := assigned_castle.global_position

	# Try a few random points; choose the first that is likely reachable.
	for i in range(patrol_pick_attempts):
		# Random point inside a circle (uniform-ish)
		var angle := randf() * TAU
		var r := sqrt(randf()) * patrol_radius
		var candidate := center + Vector2(cos(angle), sin(angle)) * r

		# Basic sanity: avoid choosing basically the same target
		# Bolt: Squared distance check (8^2 = 64)
		if candidate.distance_squared_to(_target_pos) < 64.0:
			continue

		_set_target_pos(candidate)
		return

	# Fallback: just stand near castle
	_set_target_pos(center)


func _is_patrol_target_reached(my_pos: Vector2) -> bool:
	if patrol_arrival_radius <= 0.0:
		return nav_agent.is_navigation_finished()
	return my_pos.distance_squared_to(_target_pos) <= patrol_arrival_radius * patrol_arrival_radius


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	_send_desired_velocity(safe_velocity)


func _on_nav_finished() -> void:
	emit_signal("nav_finished")


func _send_desired_velocity(velocity: Vector2) -> void:
	emit_signal("desired_velocity", velocity)


func set_castle(c: Node2D) -> void:
	assigned_castle = c
