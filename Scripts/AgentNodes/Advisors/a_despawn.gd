extends Advisor
class_name AdvisorDespawn

@export var time_until_flee: float = 30.0

var movement: Node = null
var unit_speed: Node = null
var target_memory: Node = null

var _current_target: Node3D = null
var _flee_timer: Timer = null
var _is_fleeing: bool = false


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		# 2. Grab components via the Facade
		movement = _agent.get("movement")
		unit_speed = _agent.get("unit_speed")
		target_memory = _agent.get("target_memory")

		# 3. Connect to TargetMemory
		if is_instance_valid(target_memory):
			_current_target = target_memory.get("current_target")
			if target_memory.has_signal("target_changed") and not target_memory.target_changed.is_connected(_on_target_updated):
				target_memory.target_changed.connect(_on_target_updated)

		# 4. Listen for Arrival (So we know when to delete the sheep!)
		if is_instance_valid(movement):
			if movement.has_signal("move_to_pos_finished") and not movement.move_to_pos_finished.is_connected(_on_move_finished):
				movement.move_to_pos_finished.connect(_on_move_finished)
			
			# Fallback: If the sheep gets trapped on its way out, just delete it anyway
			if movement.has_signal("stuck") and not movement.stuck.is_connected(_on_stuck):
				movement.stuck.connect(_on_stuck)

		# 5. Setup the 30-Second Time Bomb
		if not is_instance_valid(_flee_timer):
			_flee_timer = Timer.new()
			_flee_timer.one_shot = true
			_flee_timer.autostart = true # Starts ticking the moment the sheep spawns!
			_flee_timer.wait_time = time_until_flee
			_flee_timer.timeout.connect(_on_flee_timer_timeout)
			add_child(_flee_timer)


# --- EVENT TRIGGERS ---

func _on_flee_timer_timeout() -> void:
	_is_fleeing = true
	request_intent_update()


func _on_target_updated(new_target: Node3D) -> void:
	_current_target = new_target
	if _is_fleeing:
		request_intent_update()


func _on_move_finished(agent: Node) -> void:
	# If this specific sheep arrived, and it was fleeing, delete it!
	if agent == _agent and _is_fleeing:
		_agent.call_deferred("queue_free")


func _on_stuck(agent: Node) -> void:
	# Don't let fleeing sheep clog up the pathfinding if they get trapped
	if agent == _agent and _is_fleeing:
		_agent.call_deferred("queue_free")


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	# If the 30 seconds aren't up, or we have nowhere to run, stay asleep (return null)
	if not _is_fleeing or not is_instance_valid(_current_target) or not is_instance_valid(_agent):
		return null

	# The timer went off! Absolute priority (100.0) to run away!
	var intent = Intent.new(100.0, self, Intent.Type.MOVE)
	intent.target_vector = _current_target.global_position
	intent.description = "Running away to " + _current_target.name
	
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(movement): return

	if intent.type == Intent.Type.MOVE:
		# Make sure the sheep runs, not walks!
		if is_instance_valid(unit_speed) and "run_speed" in unit_speed:
			movement.max_speed = unit_speed.run_speed
			
		if movement.has_method("move_to_position"):
			movement.move_to_position(intent.target_vector)


# --- HELPERS ---

func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != start_node.get_tree().root:
		if current is AgentBase or current.get_class() == "AgentBase":
			return current as Node3D
		current = current.get_parent()
	return null
