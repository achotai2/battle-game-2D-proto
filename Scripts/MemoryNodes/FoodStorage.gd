extends Node
class_name FoodStorage

signal food_changed(current_food: int)

@export var food: int = 100:
	set(v):
		food = max(0, v)
		food_changed.emit(food)

func add_food(amount: int) -> void:
	food += amount 

func consume_food(amount: int) -> void:
	food -= amount

func get_food() -> int:
	return food
