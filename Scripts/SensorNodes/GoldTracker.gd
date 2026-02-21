extends Node
class_name GoldTracker

@export var agent: AgentBase = null

func get_distance_squared_to(target: Node3D) -> float:
	if not is_instance_valid(agent) or not is_instance_valid(target):
		return INF

	return agent.global_position.distance_squared_to(target.global_position)
