extends CanvasLayer
class_name InteractPrompt

@export_range(0.0, 64.0, 0.5) var bob_height: float = 6.0
@export_range(0.0, 10.0, 0.1) var bob_speed: float = 2.0
@export var circle: Sprite2D
@export var circleEmpty: Sprite2D

var _base_position: Vector2
var _time: float = 0.0


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	_time += delta
	position = _base_position + Vector2(0, sin(_time * bob_speed) * bob_height)


func set_base_position(screen_position: Vector2, percent_left: float) -> void:
	_base_position = screen_position
	circle.scale = percent_left * circleEmpty.scale
