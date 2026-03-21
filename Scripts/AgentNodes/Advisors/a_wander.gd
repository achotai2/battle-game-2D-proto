extends Advisor
class_name AdvisorWander

@export var wander_radius: float = 5.0
@export var min_wander_distance: float = 2.0
@export var pause_time: float = 2.0 # Wait 2 seconds between walks!

var _base_agent: AgentBase = null
var movement: Node = null
var unit_speed: Node = null

var _current_target: Node3D = null
var _wander_target_pos: Vector3 = Vector3.ZERO
var _needs_new_point: bool = true

var _pause_timer: Timer = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_base_agent):
		_base_agent = _find_root_base(self)

	if is_instance_valid(_base_agent):
		# 2. Grab components directly
		movement = _base_agent.get("movement")
		unit_speed = _base_agent.get("unit_speed")
		
		# 3. Connect to Discrete Navigation Signals
		if is_instance_valid(movement):
			if movement.has_signal("move_to_pos_finished") and not movement.move_to_pos_finished.is_connected(_on_move_finished):
				movement.move_to_pos_finished.connect(_on_move_finished)
			if movement.has_signal("stuck") and not movement.stuck.is_connected(_meander_stuck):
				movement.stuck.connect(_meander_stuck)
		
		# 4. Setup Castle Target
		if _base_agent.has_method("return_castle"):
			_current_target = _base_agent.return_castle()
		if _base_agent.has_signal("new_castle_set") and not _base_agent.new_castle_set.is_connected(_castle_updated):
			_base_agent.new_castle_set.connect(_castle_updated)

		# 5. Setup the Pause Timer
		if not is_instance_valid(_pause_timer):
			_pause_timer = Timer.new()
			_pause_timer.one_shot = true
			_pause_timer.timeout.connect(_on_pause_finished)
			add_child(_pause_timer)


# --- EVENT TRIGGERS ---

func _on_move_finished(agent: Node) -> void:
	if agent == _base_agent:
		# Take a breath! Add a tiny bit of random variance so crowd movement looks natural
		if is_instance_valid(_pause_timer):
			_pause_timer.start(pause_time + randf_range(-0.5, 0.5))
			request_intent_update()


func _on_pause_finished() -> void:
	# Ok, break is over, time to walk again
	_needs_new_point = true
	request_intent_update()


func _meander_stuck(agent: Node) -> void:
	if agent == _base_agent:
		_needs_new_point = true
		request_intent_update()


func _castle_updated(new_castle: Node3D) -> void:
	_current_target = new_castle
	_needs_new_point = true 
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_current_target) or not is_instance_valid(_base_agent):
		return null

	# If we arrived and are currently pausing, return an IDLE intent
	if is_instance_valid(_pause_timer) and not _pause_timer.is_stopped():
		var idle_intent = Intent.new(0.2, self, Intent.Type.IDLE)
		idle_intent.description = "Enjoying the view"
		return idle_intent

	if _needs_new_point:
		_needs_new_point = false # Safety first: Flip the flag BEFORE generating!
		_generate_new_wander_point()

	var intent = Intent.new(0.2, self, Intent.Type.MOVE)
	intent.target_vector = _wander_target_pos 
	intent.description = "Wandering around target"
	
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(movement): return

	if intent.type == Intent.Type.MOVE:
		if is_instance_valid(unit_speed) and "walk_speed" in unit_speed:
			movement.max_speed = unit_speed.walk_speed
			
		if movement.has_method("move_to_position"):
			movement.move_to_position(intent.target_vector)
			
	elif intent.type == Intent.Type.IDLE:
		if movement.has_method("stop"):
			movement.stop()


# --- HELPERS ---

func _generate_new_wander_point() -> void:
	var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var distance = randf_range(min_wander_distance, wander_radius)
	
	var raw_target = _current_target.global_position + Vector3(random_dir.x, 0.0, random_dir.y) * distance
	
	var map_rid: RID = _base_agent.get_world_3d().navigation_map
	_wander_target_pos = NavigationServer3D.map_get_closest_point(map_rid, raw_target)
	
	# THE FIX: No request_intent_update() here!


func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != start_node.get_tree().root:
		if current is AgentBase or current.get_class() == "AgentBase":
			return current as Node3D
		current = current.get_parent()
	return null
