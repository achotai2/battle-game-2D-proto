extends Node
class_name GoldWallet

signal gold_changed(current_gold: int)

@export var gold: int = 0:
	set(v):
		gold = max(0, v)
		gold_changed.emit(gold)


func _ready() -> void:
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	gold += amount


func subtract_gold(amount: int) -> void:
	gold -= amount


func get_gold() -> int:
	return gold
