extends Advisor
class_name AdvisorGoblinMarch

var _agent: AgentBase = null
var movement: AgentMovement = null
var unitSpeed: UnitSpeed = null
var _castle: Node3D = null


func initialize() -> void:
	# 1. Safely grab the root agent without ComponentFinder
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		movement = _agent.movement
		unitSpeed = _agent.unit_speed

		# 3. Setup Castle Tracking (Discrete Event)
		_castle = _agent.return_castle()
		if not _agent.new_castle_set.is_connected(_on_castle_updated):
			_agent.new_castle_set.connect(_on_castle_updated)


# --- EVENT TRIGGERS ---

func _on_castle_updated(new_castle: Node3D) -> void:
	_castle = new_castle
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_castle):
		return null

	# Baseline priority: March towards the castle
	var intent = Intent.new(10.0, self, Intent.Type.CHASE)
	intent.target_node = _castle
	intent.description = "Marching towards " + _castle.name
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(movement) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.CHASE:
		if is_instance_valid(unitSpeed):
			movement.max_speed = unitSpeed.run_speed
			
		# AgentMovement handles the walk/run animations automatically!
		movement.move_to_position(target.global_position)


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
