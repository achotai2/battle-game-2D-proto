extends Node
class_name GoldTracker


func get_distance_squared_to(target: Node3D) -> float:
	if owner == null:
		owner = ComponentFinder.get_base(self)

	if not is_instance_valid(owner) or not is_instance_valid(target):
		return INF

	return owner.global_position.distance_squared_to(target.global_position)
