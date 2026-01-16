extends Node
class_name TacticalWorker

signal move_to_position(pos: Vector2)
signal resume_patrol()

@export var movement: AgentMovement = null
@export var animation: AgentAnimate = null

var _agent: Node2D = null


func set_agent(my_agent: Node2D) -> void:
	_agent = my_agent


func clear_task() -> void:
	pass


func has_task() -> bool:
	return false
