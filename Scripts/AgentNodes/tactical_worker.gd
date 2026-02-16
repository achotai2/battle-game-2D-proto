extends Node
class_name TacticalWorker


var _agent: CharacterBody3D = null


func set_agent(my_agent: CharacterBody3D) -> void:
	_agent = my_agent


func set_movement(m: AgentMovement) -> void:
	pass
#	movement = m


func set_target(t: CharacterBody3D) -> void:
	# Called by detection node. Found a target.
	pass


func clear_target() -> void:
	# Called by detection node. Clear the target.
	pass
