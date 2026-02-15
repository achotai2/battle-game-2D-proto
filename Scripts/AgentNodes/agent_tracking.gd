extends Area2D
class_name AgentTracking

signal target_changed(new_target: Node2D)
signal target_lost()

enum TargetKind { ATTACKABLE, INTERACTABLE }

@export var my_agent: Node2D
@export var target_kind: TargetKind = TargetKind.ATTACKABLE

# --- Team Logic ---
@export var my_team_id: int = 1 
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = true

# --- Tuning ---
@export_enum("Nearest", "Lowest Health") var target_bias: String = "Nearest"
@export_range(0.1, 2.0) var scan_interval: float = 0.5

var current_target: Node2D = null
var _timer: Timer
var _scan_shape_query: PhysicsShapeQueryParameters2D
var _active_collision_mask: int = 0

func _ready() -> void:
	# [OPTIMIZATION] 1. Turn off the Area2D. 
	# We will not use the built-in overlapping signals.
	# This stops the engine from calculating overlaps every frame.
	monitoring = false
	monitorable = false
	
	# 2. Prepare the Shape Query (Re-usable object)
	_scan_shape_query = PhysicsShapeQueryParameters2D.new()
	_scan_shape_query.collide_with_bodies = true
	_scan_shape_query.collide_with_areas = false # Unless you target Areas?
	
	# Grab the shape from our child CollisionShape2D
	# (Assumes you have a CollisionShape2D child)
	var shape_node = find_child("CollisionShape2D")
	if shape_node and shape_node.shape:
		_scan_shape_query.shape = shape_node.shape
	else:
		push_warning("AgentTracking: No CollisionShape2D found!")
		set_physics_process(false)
		return

	# 3. Setup Timer
	_timer = Timer.new()
	_timer.wait_time = scan_interval
	_timer.autostart = true
	_timer.timeout.connect(_scan_for_targets)
	add_child(_timer)
	_timer.start(scan_interval + randf() * 0.2)
	
	# 4. Setup Mask
	_update_collision_mask()

func _update_collision_mask() -> void:
	# Determine the mask bits using your GamePhysics helper
	var mask = 0
	if target_kind == TargetKind.ATTACKABLE:
		mask = GamePhysics.get_tracking_mask(my_team_id, target_neutral, target_opposing, target_same_team)
	
	# [OPTIMIZATION] Store it in a variable, don't set the Area2D's mask
	_active_collision_mask = mask
	_scan_shape_query.collision_mask = _active_collision_mask

func _scan_for_targets() -> void:
	# [OPTIMIZATION] 2. Manual Physics Query
	# We ask the server ONCE. It costs nothing between timer ticks.
	
	# Update query transform to follow the agent
	_scan_shape_query.transform = global_transform
	
	# Execute Query (Get up to 32 results to keep it fast)
	var space_state = get_world_2d().direct_space_state
	var results = space_state.intersect_shape(_scan_shape_query, 32)
	
	if results.is_empty():
		if current_target != null:
			current_target = null
			target_lost.emit()
		return

	# 3. Find the best target
	var best_target = null
	var best_score = INF
	var my_pos = global_position
	
	for result in results:
		var body = result["collider"] # intersect_shape returns a Dictionary
		
		# Sanity check
		if body == my_agent or not is_instance_valid(body):
			continue
			
		var score = 0.0
		
		# --- Scoring Logic ---
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

	# 4. Update State
	if best_target != current_target:
		current_target = best_target
		target_changed.emit(current_target)

# ---- Public API ----

func force_scan() -> void:
	_scan_for_targets()

func setup_player(player: int) -> void:
	my_team_id = player
	_update_collision_mask()
