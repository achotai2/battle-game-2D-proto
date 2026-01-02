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


func set_target(t: Node2D) -> void:
	_target = t if is_instance_valid(t) else null
	if _target:
		combat_started.emit(_target)
		chase_target.emit(_target)
	else:
		combat_ended.emit()
		resume_patrol.emit()


func clear_target() -> void:
	_target = null
	combat_ended.emit()
	resume_patrol.emit()


func get_target() -> Node2D:
	return _target
