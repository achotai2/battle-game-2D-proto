extends Node
class_name FoodGiver

# Internal references
var _agent: AgentBase
var _storage: FoodStorage
var _display: AnimatedSprite3D
var _patience_timer: Timer

func setup(agent: AgentBase, storage: FoodStorage, display: AnimatedSprite3D, timer: Timer) -> void:
	_agent = agent
	_storage = storage
	_display = display
	_patience_timer = timer

## Gives food to the target. Returns true if successful.
func give_food(target: Node, amount: int) -> bool:
	if not is_instance_valid(_agent) or not is_instance_valid(_storage):
		return false

	if _storage.get_food() <= 0:
		return false

	# Identify receiver component
	var receiver = target
	if "hunger" in target and target.hunger:
		receiver = target.hunger
	elif target.has_method("receive_food"):
		receiver = target
	else:
		# Try to find child
		var child = target.find_child("HungerHolder", true, false)
		if child:
			receiver = child
		else:
			return false

	# Check distance
	var target_pos = target.global_position if "global_position" in target else Vector3.ZERO
	if "global_position" in receiver:
		target_pos = receiver.global_position

	var dist_sq = _agent.global_position.distance_squared_to(target_pos)

	# Using 98.0^2 from HungerHolder radius is huge (9604).
	if dist_sq > 9604.0:
		return false

	if receiver.has_method("receive_food"):
		var actual_amount = min(_storage.get_food(), amount)
		if actual_amount > 0:
			_storage.consume_food(actual_amount)
			receiver.receive_food(actual_amount)

			_play_visuals()
			return true

	return false

func _play_visuals() -> void:
	if is_instance_valid(_display):
		_display.show()
		_display.play("spawn")

	if is_instance_valid(_patience_timer):
		_patience_timer.start()

func hide_visuals() -> void:
	if is_instance_valid(_display):
		_display.hide()
