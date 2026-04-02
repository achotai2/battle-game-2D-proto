extends Area3D
class_name InteractTracking

signal target_changed(new_target: Node3D)
signal target_lost()

# --- Team Logic ---
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = true

# --- Tuning ---
@export_enum("Nearest", "Lowest Health") var target_bias: String = "Nearest"
@export_range(0.1, 2.0) var scan_interval: float = 0.5

var current_target: Node3D = null
var _team_memory: TeamMemory = null
var _my_agent: AgentBase = null
var _timer: Timer
var _scan_shape_query: PhysicsShapeQueryParameters3D
var _active_collision_mask: int = 0

func _ready() -> void:
	monitoring = false
	monitorable = false

	_scan_shape_query = PhysicsShapeQueryParameters3D.new()
	_scan_shape_query.collide_with_bodies = false
	_scan_shape_query.collide_with_areas = true

	var shape_node = find_child("CollisionShape3D")
	if shape_node and shape_node.shape:
		_scan_shape_query.shape = shape_node.shape
	else:
		print_debug("InteractTracking: No CollisionShape3D found!")
		set_physics_process(false)
		return

	_timer = Timer.new()
	_timer.wait_time = scan_interval
	_timer.autostart = false
	add_child(_timer)

func deactivate() -> void:
	if _timer:
		_timer.stop()

func activate() -> void:
	if not _timer.timeout.is_connected(_scan_for_targets):
		_timer.timeout.connect(_scan_for_targets)
	if _timer:
		_timer.start(scan_interval + randf() * 0.2)

	_my_agent = ComponentFinder.get_base(self)
	_team_memory = _my_agent.get("team") if _my_agent.get("team") else _my_agent.get("team_memory")

	if _team_memory and not _team_memory.team_changed.is_connected(_on_team_changed):
		_team_memory.team_changed.connect(_on_team_changed)
		_on_team_changed(_team_memory.return_team())
	else:
		_on_team_changed(0)

	if _team_memory:
		_update_collision_mask(_team_memory.return_team())


func _on_team_changed(new_team: int) -> void:
	_update_collision_mask(new_team)


func _update_collision_mask(_team_id: int) -> void:
	_active_collision_mask = GamePhysics.get_interacting_mask(_team_id, target_neutral, target_opposing, target_same_team)
	_scan_shape_query.collision_mask = _active_collision_mask


func _scan_for_targets() -> void:
	_scan_shape_query.transform = global_transform

	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(_scan_shape_query, 32)

	var best_target = null
	var best_score = INF
	var my_pos = global_position

	for result in results:
		var body = result["collider"]

		# Skip invalid bodies, and skip ourselves!
		if not is_instance_valid(body) or body == _my_agent:
			continue
		if body is not Interactable:
			continue
		if not body.can_interact(_my_agent):
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

	# --- NEW: Consolidated Target Logic ---
	if best_target == null:
		# If we found nothing valid, but we used to have a target, drop it!
		if current_target != null:
			current_target = null
			target_lost.emit()
			
	elif best_target != current_target:
		# If we found a NEW valid target, switch to it!
		current_target = best_target
		target_changed.emit(current_target)


func get_candidates() -> Array[Node3D]:
	_scan_shape_query.transform = global_transform
	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(_scan_shape_query, 32)
	var candidates: Array[Node3D] = []
	for result in results:
		var body = result["collider"]
		if is_instance_valid(body) and body is Interactable:
			candidates.append(body)
	return candidates


func force_scan() -> void:
	_scan_for_targets()
