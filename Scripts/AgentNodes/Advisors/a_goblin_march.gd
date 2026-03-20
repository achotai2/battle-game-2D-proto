extends Advisor
class_name AdvisorGoblinMarch

var _agent: AgentBase = null
var movement: AgentMovement = null
var unitSpeed: UnitSpeed = null


func initialize() -> void:
	if not _agent:
		_agent = ComponentFinder.get_base(self)

	if _agent:
		if not movement:
			movement = _agent.movement

		if not unitSpeed:
			unitSpeed = _agent.unit_speed

		if not _agent.new_castle_set.is_connected(_castle_updated):
			_agent.new_castle_set.connect(_castle_updated)

func _castle_updated(new_castle: Node3D) -> void:
	request_intent_update()


func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_agent.return_castle()):
		return null

	var target = _agent.return_castle()

	# Medium priority fallback: March towards the castle
	var intent = Intent.new(10.0, self, Intent.Type.CHASE)
	intent.target_node = target
	intent.description = "Marching towards " + target.name
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.CHASE:
		if movement:
			if unitSpeed:
				movement.max_speed = unitSpeed.run_speed
			movement.move_to_position(target.global_position)
