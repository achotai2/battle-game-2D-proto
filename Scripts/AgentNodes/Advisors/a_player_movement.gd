extends Advisor
class_name AdvisorPlayerMovement

var controls: Node = null
var movement: AgentMovement = null
var unit_speed: Node = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)
		
	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		controls = _agent.get("player_controls")
		movement = _agent.get("movement")
		unit_speed = _agent.get("unit_speed")
		
		# 3. Connect to the discrete input signal
		if is_instance_valid(controls):
			if not controls.input_changed.is_connected(_on_input_changed):
				controls.input_changed.connect(_on_input_changed)


# --- EVENT TRIGGERS ---

func _on_input_changed() -> void:
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(controls): return null

	var dir: Vector3 = Vector3.ZERO
	if controls.has_method("get_input_vector"):
		dir = controls.get_input_vector()

	# Deadzone control feature, for joysticks.
	if dir.length_squared() > 0.01:
		var intent = Intent.new(99.0, self, Intent.Type.PLAYER_MOVE)
		intent.direction = dir
		intent.description = "Player Input Move"
		return intent

	# THE FIX: Return null instead of a 1.0 IDLE Intent!
	# By returning null, the Brain instantly falls back to checking lower-priority 
	# advisors, allowing the 50.0 Auto-Attack to seamlessly take over.
	return null


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(movement): return

	if intent.type == Intent.Type.PLAYER_MOVE:
		# Apply stats and move! 
		# AgentMovement handles the play_walk() visuals automatically.
		if is_instance_valid(unit_speed) and "run_speed" in unit_speed:
			movement.max_speed = unit_speed.run_speed
			
		if movement.has_method("move_in_direction"):
			movement.move_in_direction(intent.direction)


func on_lose_control() -> void:
	# If the player stops pressing WASD (and we return null), OR if a 100.0 Interact overrides us,
	# we cleanly halt the physical momentum!
	if is_instance_valid(movement) and movement.has_method("stop"):
		movement.stop()


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
