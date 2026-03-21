extends Advisor
class_name AdvisorFlee

var _agent: AgentBase = null
var _tracker: Tracker = null
var _movement: AgentMovement = null
var _unit_speed: UnitSpeed = null
var _castle: Node3D = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		_tracker = _agent.tracker
		_movement = _agent.movement
		_unit_speed = _agent.unit_speed

		# 3. Connect to Tracker for purely event-driven updates (No timers needed!)
		if is_instance_valid(_tracker):
			if not _tracker.target_changed.is_connected(_on_target_changed):
				_tracker.target_changed.connect(_on_target_changed)
			if not _tracker.target_lost.is_connected(_on_target_lost):
				_tracker.target_lost.connect(_on_target_lost)

		# 4. Get the castle to run back to
		_castle = _agent.return_castle()
		if not _agent.new_castle_set.is_connected(_on_castle_updated):
			_agent.new_castle_set.connect(_on_castle_updated)


# --- EVENT TRIGGERS ---

func _on_target_changed(_target: Node3D) -> void:
	request_intent_update()


func _on_target_lost() -> void:
	request_intent_update()


func _on_castle_updated(new_castle: Node3D) -> void:
	_castle = new_castle
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_tracker) or not is_instance_valid(_castle):
		return null

	# Are there enemies nearby?
	var enemies = _tracker.get_candidates()
	if enemies.is_empty():
		return null

	# We are scared! Emit the 30 priority intent to run home.
	# (Assuming you have FLEE or MOVE in your Intent.Type enum)
	var intent = Intent.new(30.0, self, Intent.Type.FLEE)
	
	# Pass the Castle's exact coordinates as the target
	intent.target_vector = _castle.global_position
	intent.description = "Fleeing to castle!"
	
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_movement): return

	if intent.type == Intent.Type.FLEE:
		# Sprint!
		if is_instance_valid(_unit_speed):
			_movement.max_speed = _unit_speed.run_speed
			
		# AgentMovement handles the walk/run animations automatically now
		_movement.move_to_position(intent.target_vector)


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
