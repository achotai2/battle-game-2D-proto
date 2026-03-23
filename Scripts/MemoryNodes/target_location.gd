extends Node
class_name TargetMemory

signal target_changed(new_target: Node3D)

var current_target: Node3D = null

func set_target(target: Node3D) -> void:
	current_target = target
	target_changed.emit(current_target)

func clear_target() -> void:
	current_target = null
	target_changed.emit(null)
