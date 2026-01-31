extends Node2D
class_name GameResource

## The amount of gold in this pile.
@export var _amount: int = 0

@export var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	if is_instance_valid(_sprite):
		_sprite.play("spawn")


func set_amount(a: int) -> void:
	_amount = a


func how_much() -> int:
	return _amount
