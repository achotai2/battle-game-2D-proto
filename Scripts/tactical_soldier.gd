extends Node
class_name TacticalSoldier

# These are intentionally high-level. The Agent decides how to implement them.
signal chase_target(target: Node2D)
signal resume_patrol()
signal move_to_position(pos: Vector2)

# Optional: you can expose this if you want the agent to change movement state when fighting
signal combat_started(target: Node2D)
signal combat_ended()

var _target: Node2D = null
var _agent: Node2D = null


func set_target(t: Node2D) -> void:
	# Called by detection node. Found a target.
	_target = t if is_instance_valid(t) else null
	if _target:
		combat_started.emit(_target)
		chase_target.emit(_target)
	else:
		combat_ended.emit()
		resume_patrol.emit()


func clear_target() -> void:
	# Called by detection node. Clear the target.
	_target = null
	combat_ended.emit()
	resume_patrol.emit()


func detection_refreshed(t: Node2D) -> void:
	# Called by detection node.
	if t != null:
		set_target(t)
	else:
		clear_target()


func get_target() -> Node2D:
	return _target


func set_agent(my_agent: Node2D) -> void:
	_agent = my_agent


func attack_finished() -> void:
	# Called by signal from animation when attack animation finishes.
	if is_instance_valid(_agent) and is_instance_valid(_agent.movement):
		_agent.movement.un_freeze()
