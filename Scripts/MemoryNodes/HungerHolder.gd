extends Node3D # Downgraded from Area3D! No more wasted physics calculations.
class_name HungerHolder

signal food_changed(new_amount: int)
signal food_handed

# --- VISUALS ---
@export var food_display: AnimatedSprite3D

# --- CONFIGURATION ---
@export var lose_food: bool = true
@export var time_tick: float = 5.0
@export var min_hunger: int = 0
@export var max_hunger_priority: float = 20.0
@export var hunger_start_threshold: int = 50

# --- TIMERS ---
@export var _patience_timer: Timer = null
@export var _hunger_timer: Timer = null
@export var _food_gone_timer: Timer = null

# --- STATE ---
var _agent: AgentBase = null
var _food_backing: int = 100

# Sub-components
var _food_storage: Node = null
var _food_giver: Node = null
var _food_receiver: Node = null
var _food_sensor: Node = null


func _ready() -> void:
	pass

func deactivate() -> void:
	if _hunger_timer:
		_hunger_timer.stop()
	if _patience_timer:
		_patience_timer.stop()
	if _food_gone_timer:
		_food_gone_timer.stop()

func activate() -> void:
	# 1. Safely grab the root agent
	_agent = _find_root_base(self)

	# 2. Hide visuals by default
	if is_instance_valid(food_display):
		food_display.hide()

	# 3. Setup the internal data components
	_setup_components()

	# 4. Setup the continuous hunger tick (Discrete event generator!)
	if is_instance_valid(_hunger_timer):
		_hunger_timer.wait_time = time_tick
		if not _hunger_timer.timeout.is_connected(_on_hunger_timer_timeout):
			_hunger_timer.timeout.connect(_on_hunger_timer_timeout)
		
		# Stagger start times so 100 peasants don't all get hungry on the exact same frame
		var stagger_time = randf_range(0.1, time_tick)
		_hunger_timer.start(stagger_time)


func _setup_components() -> void:
	# Note: Assuming FoodStorage, FoodSensor, FoodGiver, and FoodReceiver are 
	# custom RefCounted or Node classes you built elsewhere!
	
	_food_storage = FoodStorage.new()
	_food_storage.name = "FoodStorage"
	_food_storage.food = _food_backing 
	add_child(_food_storage)
	
	_food_sensor = FoodSensor.new()
	_food_sensor.name = "FoodSensor"
	_food_sensor.agent = _agent
	add_child(_food_sensor)
	
	_food_giver = FoodGiver.new()
	_food_giver.name = "FoodGiver"
	if _food_giver.has_method("setup"):
		_food_giver.setup(_agent, _food_storage, food_display, _patience_timer)
	add_child(_food_giver)

	_food_receiver = FoodReceiver.new()
	_food_receiver.name = "FoodReceiver"
	if _food_receiver.has_method("setup"):
		_food_receiver.setup(_agent, _food_storage, food_display, _food_gone_timer)
	add_child(_food_receiver)
	
	# THE FIX: We deleted the entire _setup_advisor() function! 
	# The Brain manages the AdvisorHunger script now.


# --- DATA ACCESS ---

func get_food() -> int:
	if is_instance_valid(_food_storage):
		return _food_storage.food
	return _food_backing


func set_food(amount: int) -> void:
	_food_backing = amount
	if is_instance_valid(_food_storage):
		_food_storage.food = amount
		
	# Broadcast the change so the sleeping AdvisorHunger wakes up!
	food_changed.emit(amount)


# --- EVENT TRIGGERS ---

func _on_hunger_timer_timeout() -> void:
	if lose_food and is_instance_valid(_food_storage):
		if _food_storage.has_method("consume_food"):
			_food_storage.consume_food(1)
			
			# Ensure we emit the signal when the sub-component changes the math!
			food_changed.emit(_food_storage.food)

	# Restart the timer automatically
	if is_instance_valid(_hunger_timer):
		_hunger_timer.start(time_tick)


# --- INTERACTION LOGIC ---

func give_food(target: Node, amount: int) -> void:
	if is_instance_valid(_food_giver) and _food_giver.has_method("give_food"):
		if _food_giver.give_food(target, amount):
			food_handed.emit()
			food_changed.emit(get_food())


func receive_food(amount: int) -> void:
	if is_instance_valid(_food_receiver) and _food_receiver.has_method("receive_food"):
		_food_receiver.receive_food(amount)
		food_changed.emit(get_food())


func _on_delivery_patience_timeout() -> void:
	if is_instance_valid(_food_giver) and _food_giver.has_method("hide_visuals"):
		_food_giver.hide_visuals()


func _on_food_gone_timeout() -> void:
	if is_instance_valid(_food_receiver) and _food_receiver.has_method("hide_visuals"):
		_food_receiver.hide_visuals()


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase or current.get_class() == "AgentBase":
			return current as AgentBase
		current = current.get_parent()
	return null
