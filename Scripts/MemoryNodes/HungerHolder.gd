extends Area3D
class_name HungerHolder

signal food_handed

## The scene used to represent food on the ground when dropped.
@export var food_display: AnimatedSprite3D

## Connects to the agents move node to call commands to it.
@export var movement: AgentMovement

## Connects to the agents food tasker to call work when needed.
@export var food_tasker: MinionTasker

## Current amount of food stomach held.
@export var food: int = 100:
	set(v):
		if _food_storage:
			_food_storage.food = v
		else:
			_food_backing = v
	get:
		if _food_storage:
			return _food_storage.food
		return _food_backing

var _food_backing: int = 100

## Time ticks for hunger to automatically go down.
@export var time_tick: int = 5

## Min hunger before seeking food.
@export var min_hunger: int = 0

## Max priority for food seeking (at min_hunger).
@export var max_hunger_priority: int = 20

## Hunger level to start seeking food (linear ramp to max_priority).
@export var hunger_start_threshold: int = 50

## How long will agent try to deliver food before giving up.
@export var _patience_timer: Timer = null

@export var _hunger_timer: Timer = null

## Time food stays in hand after received before despawning, for visual purposes only.
@export var _food_gone_timer: Timer = null

# Lose food with time.
@export var lose_food: bool = true


# Internal components
var _agent: AgentBase
var _food_storage: FoodStorage
var _food_giver: FoodGiver
var _food_receiver: FoodReceiver
var _food_sensor: FoodSensor
var _hunger_advisor: HungerAdvisor


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_agent = get_parent() as AgentBase
	# If parent is 'Memory' node, get grandparent
	if not _agent and get_parent().name == "Memory":
		_agent = get_parent().get_parent() as AgentBase

	_setup_components()

	if is_instance_valid(food_display):
		food_display.hide()

	if _hunger_timer:
		_hunger_timer.wait_time = time_tick
		var stagger_time = randf_range(0.0, 1.0)
		_hunger_timer.start(stagger_time)


func _setup_components() -> void:
	# Create Storage
	_food_storage = FoodStorage.new()
	_food_storage.name = "FoodStorage"
	_food_storage.food = _food_backing # Initialize with backed value
	add_child(_food_storage)
	
	# Create Sensor
	_food_sensor = FoodSensor.new()
	_food_sensor.name = "FoodSensor"
	_food_sensor.agent = _agent
	add_child(_food_sensor)
	
	# Create Giver
	_food_giver = FoodGiver.new()
	_food_giver.name = "FoodGiver"
	_food_giver.setup(_agent, _food_storage, food_display, _patience_timer)
	add_child(_food_giver)

	# Create Receiver
	_food_receiver = FoodReceiver.new()
	_food_receiver.name = "FoodReceiver"
	_food_receiver.setup(_agent, _food_storage, food_display, _food_gone_timer)
	add_child(_food_receiver)

	# Create Advisor (deferred to ensure AgentBase and Brain are ready)
	call_deferred("_setup_advisor")

func _setup_advisor() -> void:
	if not is_instance_valid(_agent):
		return
		
	# AgentBase initializes Brain in apply_role which is called in _ready.
	# Since this is deferred, it should be ready.
	if not _agent.brain:
		return

	if _hunger_advisor: # Already created
		return

	_hunger_advisor = HungerAdvisor.new()
	_hunger_advisor.name = "AdvisorHunger"
	# Setup references
	# Note: food_tasker might be null if not assigned yet?
	# AgentBase assigns foodTasker ref in _connect_all_refs.
	# But hunger.food_tasker is an export on HungerHolder.
	# If the scene has it assigned, it's fine.
	
	_hunger_advisor.setup(_food_storage, food_tasker)
	_hunger_advisor.min_hunger = min_hunger
	_hunger_advisor.hunger_start_threshold = hunger_start_threshold
	_hunger_advisor.max_priority = max_hunger_priority
	_hunger_advisor.agent = _agent
	
	_agent.brain.add_child(_hunger_advisor)


func _process(delta: float) -> void:
	pass


func set_movement(m: AgentMovement) -> void:
	movement = m


func _on_hunger_timer_timeout() -> void:
	if lose_food and _food_storage:
		_food_storage.consume_food(1)

	if _hunger_timer:
		_hunger_timer.start(time_tick)


## Command the agent to run to a target and give them the food.
func give_food(target: Node, amount: int) -> void:
	if _food_giver:
		if _food_giver.give_food(target, amount):
			food_handed.emit()


func receive_food(amount: int) -> void:
	if _food_receiver:
		_food_receiver.receive_food(amount)


func _on_delivery_patience_timeout() -> void:
	if _food_giver:
		_food_giver.hide_visuals()


func _on_food_gone_timeout() -> void:
	if _food_receiver:
		_food_receiver.hide_visuals()

# Legacy: Area3D body entered used for giving food logic previously.
# Now handled by Advisor distance checks or Giver distance checks.
# But keeping signal connection safe.
func _on_body_entered(body: Node3D) -> void:
	pass
