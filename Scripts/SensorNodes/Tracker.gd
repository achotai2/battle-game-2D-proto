extends Area3D
class_name Tracker

signal target_changed(new_target: Node3D)
signal target_lost()

# --- Tracking Logic ---
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = true

# --- Tuning ---
@export_enum("Nearest", "Lowest Health") var target_bias: String = "Nearest"
@export_range(0.1, 2.0) var scan_interval: float = 0.5

var current_target: Node3D = null
var _timer: Timer
var _scan_shape_query: PhysicsShapeQueryParameters3D
var _active_collision_mask: int = 0

var _my_base: Node3D = null
var _my_team = null


func _ready() -> void:
	# We turn off standard Area3D monitoring because we use manual server queries!
	monitoring = false
	monitorable = false
	
	_scan_shape_query = PhysicsShapeQueryParameters3D.new()
	_scan_shape_query.collide_with_bodies = true
	_scan_shape_query.collide_with_areas = false
	
	var shape_node = find_child("CollisionShape3D")
	if shape_node and shape_node.shape:
		_scan_shape_query.shape = shape_node.shape
	else:
		push_warning("Tracker: No CollisionShape3D found!")
		set_physics_process(false)
		return

	# Setup Timer
	_timer = Timer.new()
	_timer.wait_time = scan_interval
	_timer.autostart = false
	add_child(_timer)


func deactivate() -> void:
	if _timer:
		_timer.stop()
	if _timer.timeout.is_connected(_scan_for_targets):
		_timer.timeout.disconnect(_scan_for_targets)

	if is_instance_valid(_my_team) and _my_team.has_signal("team_changed"):
		if _my_team.team_changed.is_connected(_team_changed):
			_my_team.team_changed.disconnect(_team_changed)


func activate() -> void:
	if not _timer.timeout.is_connected(_scan_for_targets):
		_timer.timeout.connect(_scan_for_targets)

	# 1. Safely grab the team without ComponentFinder
	_my_base = _find_root_base(self)
	if is_instance_valid(_my_base):
		_my_team = _my_base.get("team")
		if not _my_team:
			_my_team = _my_base.get("team_memory")

		if is_instance_valid(_my_team):
			if not _my_team.team_changed.is_connected(_team_changed):
				_my_team.team_changed.connect(_team_changed)
			
			if _my_team.has_method("return_team"):
				_team_changed(_my_team.return_team())

	# 2. Start the physics sweep heartbeat
	if _timer:
		# Adding a slight random offset prevents all units from sweeping on the exact same frame!
		_timer.start(scan_interval + randf() * 0.2) 


func _team_changed(new_team: int) -> void:
	# Calculate and cache the collision mask whenever the team changes
	var mask = GamePhysics.get_tracking_mask(new_team, target_neutral, target_opposing, target_same_team)
	_active_collision_mask = mask
	_scan_shape_query.collision_mask = _active_collision_mask


func _scan_for_targets() -> void:
	_scan_shape_query.transform = global_transform
	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(_scan_shape_query, 32)
	
	if results.is_empty():
		if current_target != null:
			current_target = null
			target_lost.emit()
		return

	var best_target = null
	var best_score = INF
	var my_pos = global_position
	
	for result in results:
		var body = result["collider"]
		
		# Ignore ourselves and deleted bodies
		if body == _my_base or not is_instance_valid(body):
			continue
			
		var score = 0.0
		
		if target_bias == "Nearest":
			score = my_pos.distance_squared_to(body.global_position)
		elif target_bias == "Lowest Health":
			if body.has_method("get_health_percent"):
				score = body.get_health_percent()
			else:
				score = 100.0
		
		if score < best_score:
			best_score = score
			best_target = body

	# Update State
	if best_target != current_target:
		current_target = best_target
		target_changed.emit(current_target)


func get_candidates() -> Array[Node3D]:
	_scan_shape_query.transform = global_transform
	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(_scan_shape_query, 32)
	
	var candidates: Array[Node3D] = []
	for result in results:
		var body = result["collider"]
		if body != _my_base and is_instance_valid(body):
			candidates.append(body)
			
	return candidates


# --- HELPERS ---

func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase or current.has_method("return_castle"):
			return current as Node3D
		current = current.get_parent()
	return null

func force_scan() -> void:
	_scan_for_targets()
