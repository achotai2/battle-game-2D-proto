extends RefCounted
class_name Intent

enum Type { IDLE, MOVE, CHASE, ATTACK, WORK, FLEE, PLAYER_MOVE, PLAYER_INTERACT }

var priority: float = 0.0
var advisor: Node = null
var type: Type = Type.IDLE
var target_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var target_node: Node3D = null
var description: String = ""

func _init(_priority: float, _advisor: Node, _type: Type) -> void:
	priority = _priority
	advisor = _advisor
	type = _type
