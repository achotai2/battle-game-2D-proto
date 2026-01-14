extends Area2D
class_name Interactable

signal interaction_started(interactor: Node2D)
signal interaction_finished(interactor: Node2D)

@export var interaction_time: float = 0.0
@export var one_shot: bool = false
@export var requires_same_team: bool = false
@export var allows_neutral: bool = true
@export var priority: int = 0
@export var icon_type: StringName = &""
@export var prompt_anchor: Node2D

var _disabled: bool = false
var _active_interactor: Node2D = null


func can_interact(interactor: Node2D) -> bool:
	if _disabled:
		return false
	if _active_interactor != null and _active_interactor != interactor:
		return false

	var interactor_team := _get_team_id(interactor)
	if not allows_neutral and interactor_team == 0:
		return false

	if requires_same_team:
		var owner_team := _get_team_id(get_parent())
		if interactor_team != owner_team:
			return false

	return true


func begin_interact(interactor: Node2D) -> void:
	if _active_interactor != null:
		return
	if not can_interact(interactor):
		return

	_active_interactor = interactor
	interaction_started.emit(interactor)


func finish_interact(interactor: Node2D) -> void:
	if _active_interactor != interactor:
		return

	_active_interactor = null
	if one_shot:
		_disable_interaction()
	interaction_finished.emit(interactor)


func get_interaction_time() -> float:
	return interaction_time


func get_prompt_position() -> Vector2:
	var anchor := prompt_anchor
	if anchor == null:
		anchor = get_node_or_null("PromptAnchor") as Node2D
	if is_instance_valid(anchor):
		return anchor.global_position
	if get_parent() is Node2D:
		return (get_parent() as Node2D).global_position
	return global_position


func _get_team_id(entity: Node) -> int:
	if entity is AgentBase:
		return (entity as AgentBase).player
	return 0


func _disable_interaction() -> void:
	_disabled = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
