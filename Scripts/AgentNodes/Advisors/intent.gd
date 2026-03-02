extends RefCounted
class_name Intent

enum Type { IDLE, MOVE, CHASE, ATTACK, WORK, FLEE, PLAYER_MOVE, PLAYER_INTERACT }

var priority: float = 0.0
var advisor: Node = null
var type: Type = Type.IDLE
var target_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var description: String = ""
var target_node: Node3D = null # Used when following a specific unit or building
var target_vector: Vector3 = Vector3.ZERO # <--- ADD THIS LINE for raw coordinates!

func _init(_priority: float, _advisor: Node, _type: Type) -> void:
	priority = _priority
	advisor = _advisor
	type = _type
