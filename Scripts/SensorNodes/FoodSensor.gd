extends Node
class_name FoodSensor

@export var agent: AgentBase

func get_distance_squared_to(target: Node) -> float:
	if not is_instance_valid(agent) or not is_instance_valid(target):
		return INF

	if not "global_position" in target:
		return INF

	return agent.global_position.distance_squared_to(target.global_position)

func get_closest_food_source() -> Node:
	# Placeholder for future logic to find food dropped on ground or WorkSites.
	# For now, advisors use MinionTasker to find work sites.
	return null
