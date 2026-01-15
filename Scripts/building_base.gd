extends StaticBody2D
class_name BuildingBase

@export var castle: Node2D
@export var worksite: WorkSite
@export var player: int = 0


func _ready() -> void:
	if is_instance_valid(worksite) and is_instance_valid(castle):
		worksite.assign_boss(self)


func return_castle() -> Node:
	return castle


func return_position() -> Vector2:
	return global_position
