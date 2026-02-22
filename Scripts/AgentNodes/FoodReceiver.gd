extends Node
class_name FoodReceiver

# Internal references
var _agent: AgentBase
var _storage: FoodStorage
var _display: AnimatedSprite3D
var _gone_timer: Timer

func setup(agent: AgentBase, storage: FoodStorage, display: AnimatedSprite3D, timer: Timer) -> void:
	_agent = agent
	_storage = storage
	_display = display
	_gone_timer = timer

func receive_food(amount: int) -> void:
	if not is_instance_valid(_storage):
		return

	_storage.add_food(amount)

	_play_visuals()

func _play_visuals() -> void:
	if is_instance_valid(_display):
		_display.show()
		_display.play("spawn")

	if is_instance_valid(_gone_timer):
		_gone_timer.start()

func hide_visuals() -> void:
	if is_instance_valid(_display):
		_display.hide()
