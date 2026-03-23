extends Advisor
class_name AdvisorGoblinMarch

var movement: AgentMovement = null
var unitSpeed: UnitSpeed = null
var target_memory: TargetMemory = null
var _current_target: Node3D = null


func initialize() -> void:
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		movement = _agent.movement
		unitSpeed = _agent.unit_speed

		# FAST TRACK: Read the cache directly! No ComponentFinder!
		target_memory = _agent.target_memory 
		
		if is_instance_valid(target_memory):
			_current_target = target_memory.current_target # Grab initial target
			if not target_memory.target_changed.is_connected(_on_target_updated):
				target_memory.target_changed.connect(_on_target_updated)


# --- EVENT TRIGGERS ---

func _on_target_updated(new_target: Node3D) -> void:
	_current_target = new_target
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_current_target):
		return null

	# Baseline priority: March towards our assigned target
	var intent = Intent.new(10.0, self, Intent.Type.CHASE)
	intent.target_node = _current_target
	intent.description = "Marching towards " + _current_target.name
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(movement) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.CHASE:
		if is_instance_valid(unitSpeed):
			movement.max_speed = unitSpeed.run_speed
			
		movement.move_to_position(target.global_position)


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
