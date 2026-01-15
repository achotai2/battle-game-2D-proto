extends StaticBody2D
class_name BuildingBase

@export var castle: Node2D
@export var player: int = 0
@export var buildWorksite: WorkSite
@export var interactable: Interactable
@export var buildState: StringName = &"constructing"

var _built: StringName = &"built"
var _destroyed: StringName = &"destroyed"
var _constructing: StringName = &"constructing"


func _ready() -> void:
	if is_instance_valid(buildWorksite):
		buildWorksite.assign_boss(self)
		
		buildWorksite.work_completed.connect(_work_completed)

	if is_instance_valid(interactable):
		interactable.interaction_finished.connect(_interact_finished)


func return_castle() -> Node:
	return castle


func return_position() -> Vector2:
	return global_position


func _interact_finished(interactor: Node2D) -> void:
	if buildState == _destroyed:
		buildState = _constructing


func _work_completed(site: WorkSite) -> void:
	if buildState == _built:
		pass
