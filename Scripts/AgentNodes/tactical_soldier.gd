extends Node
class_name TacticalSoldier

# These are intentionally high-level. The Agent decides how to implement them.
signal chase_target(target: CharacterBody2D)
signal move_to_position(pos: Vector2)

# Optional: you can expose this if you want the agent to change movement state when fighting
signal combat_started(target: CharacterBody2D)
signal combat_ended()

@export var movement: AgentMovement = null
@export var soldier_priority: int = 6

var _target: CharacterBody2D = null
var _agent: CharacterBody2D = null


func set_target(t: CharacterBody2D) -> void:
	# Called by detection node. Found a target.
	_target = t if is_instance_valid(t) else null
	if _target:
		combat_started.emit(_target)
		_chase_target(_target)
	else:
		combat_ended.emit()


func clear_target() -> void:
	# Called by detection node. Clear the target.
	_target = null
	combat_ended.emit()


func detection_refreshed(t: CharacterBody2D) -> void:
	# Called by detection node.
	pass


func get_target() -> CharacterBody2D:
	return _target


func set_agent(my_agent: CharacterBody2D) -> void:
	_agent = my_agent


func set_movement(m: AgentMovement) -> void:
	movement = m


func _chase_target(target: CharacterBody2D) -> void:
	if is_instance_valid(movement):
		movement.command_chase_target(target, soldier_priority)
	chase_target.emit(target)
