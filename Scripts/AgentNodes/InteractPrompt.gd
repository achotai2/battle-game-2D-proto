extends Node3D
class_name InteractPrompt

const ICONS := {
	BuildingDefs.IconType.TAX: preload("res://Art/Icons/TaxIcon.png"),
	BuildingDefs.IconType.CONSTRUCT: preload("res://Art/Icons/ConstructIcon.png"),
	BuildingDefs.IconType.CUT: preload("res://Art/Icons/TreeCutIcon.png"),
	BuildingDefs.IconType.ARCHER: preload("res://Art/Icons/TransformArcherIcon.png"),
} 

@export_range(0.0, 1.0, 0.01) var bob_height: float = 0.2
@export_range(0.0, 10.0, 0.1) var bob_speed: float = 2.0
@export var visuals: Node3D
@export var circle: Sprite3D
@export var circleEmpty: Sprite3D
@export var type_icon: Sprite3D
@export var costLabel: Label3D

var _time: float = 0.0

func _ready() -> void:
	if visuals == null:
		push_warning("InteractPrompt: 'visuals' Node3D export is not set.")
	if circle == null:
		push_warning("InteractPrompt: 'circle' Sprite3D export is not set.")
	if circleEmpty == null:
		push_warning("InteractPrompt: 'circleEmpty' Sprite3D export is not set.")
	if costLabel == null:
		push_warning("InteractPrompt: 'costLabel' Label3D export is not set.")


func _process(delta: float) -> void:
	_time += delta

	var bob_y := sin(_time * bob_speed) * bob_height
	if visuals:
		visuals.position.y = bob_y


func set_world_target(world_pos: Vector3, percent_left: float, world_offset: Vector3 = Vector3(0, 0, 0)) -> void:
	global_position = world_pos + world_offset
	_set_percent(percent_left)


func set_screen_target(_screen_pos: Vector3, percent_left: float) -> void:
	# Deprecated/Unused in 3D but kept for API compatibility if needed
	pass


func show_prompt() -> void:
	visible = true


func hide_prompt() -> void:
	visible = false


func _set_percent(percent_left: float) -> void:
	var p = clamp(percent_left, 0.0, 1.0)

	if circle and circleEmpty:
		# Scale uniformly based on the empty circle's scale
		circle.scale = circleEmpty.scale * p


func follow_target(target: CharacterBody3D, percent_left: float, world_offset: Vector3 = Vector3(0, 0, 0)) -> void:
	if not is_instance_valid(target):
		return
	set_world_target(target.global_position, percent_left, world_offset)


func reset_bob_phase() -> void:
	_time = 0.0


func update_icon(_icon_type: BuildingDefs.IconType) -> void:
	if _icon_type == BuildingDefs.IconType.NONE:
		if type_icon: type_icon.hide()
	else:
		if type_icon:
			type_icon.show()
			type_icon.texture = ICONS.get(_icon_type, ICONS[BuildingDefs.IconType.CONSTRUCT])


func update_cost(_cost: int) -> void:
	if costLabel:
		costLabel.text = str(_cost)
