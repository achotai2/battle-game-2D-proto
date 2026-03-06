extends Advisor
class_name AdvisorWander

var wander_radius: float = 5.0
var min_wander_distance: float = 2.0

var movement: AgentMovement = null
var _current_target: Node3D = null
var _base_agent: AgentBase = null
var unit_speed: UnitSpeed = null

# State tracking
var _wander_target_pos: Vector3 = Vector3.ZERO
var _needs_new_point: bool = true


func initialize() -> void:
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")

	if not unit_speed:
		unit_speed = ComponentFinder.get_component(self, "UnitSpeed")

	if not _base_agent:
		_base_agent = ComponentFinder.get_base(self)
	
	# Wire up the movement signal so we know when we arrive
	if movement and not movement.move_to_pos_finished.is_connected(_on_move_finished):
		movement.move_to_pos_finished.connect(_on_move_finished)
	if movement and not movement.stuck.is_connected(_meander_stuck):
		movement.stuck.connect(_meander_stuck)
	
	if _base_agent:
		if not _current_target:
			_current_target = _base_agent.return_castle()
		
		if not _base_agent.new_castle_set.is_connected(_castle_updated):
			_base_agent.new_castle_set.connect(_castle_updated)


func get_intent() -> Intent:
	if not _current_target or not _base_agent:
		return null

	# If we arrived at our last point, generate a new one safely on the navmesh
	if _needs_new_point:
		_generate_new_wander_point()
		_needs_new_point = false

	# Wander is usually a low-priority fallback behavior, so we score it low (e.g., 0.2)
	var intent = Intent.new(0.2, self, Intent.Type.MOVE)
	
	# Note: Ensure your Intent class has a Vector3 variable (like target_vector) 
	# since we are navigating to a coordinate, not a Node3D!
	intent.target_vector = _wander_target_pos 
	intent.description = "Wandering around target"
	
	return intent


func enact_intent(intent: Intent) -> void:
	if not movement: return

	if intent.type == Intent.Type.MOVE:
		if unit_speed:
			movement.max_speed = unit_speed.walk_speed
		movement.move_to_position(intent.target_vector)


func _generate_new_wander_point() -> void:
	# 1. Get a random 2D direction (X and Z axis)
	var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var distance = randf_range(min_wander_distance, wander_radius)
	
	# 2. Apply it to the Castle's position
	var raw_target = _current_target.global_position + Vector3(random_dir.x, 0.0, random_dir.y) * distance
	
	# 3. SAFETY CHECK: Ask the Navigation Server to snap this raw coordinate to the nearest valid NavMesh polygon
	var map_rid: RID = _base_agent.get_world_3d().navigation_map
	_wander_target_pos = NavigationServer3D.map_get_closest_point(map_rid, raw_target)


func _on_move_finished(agent: AgentBase) -> void:
	# Only flip the flag if THIS agent is the one that finished moving
	if agent == _base_agent:
		_needs_new_point = true


func _meander_stuck(agent: AgentBase) -> void:
	if agent == _base_agent:
		_needs_new_point = true


func _castle_updated(new_castle: Node3D) -> void:
	_current_target = new_castle
	_needs_new_point = true # Force a new point to be generated around the new castle
