extends Area2D
class_name HungerHolder

signal food_handed

## The scene used to represent food on the ground when dropped.
@export var food_display: AnimatedSprite2D

## Connects to the agents move node to call commands to it.
@export var movement: AgentMovement

## Connects to the agents food tasker to call work when needed.
@export var food_tasker: MinionTasker

## Current amount of food stomach held.
@export var food: int = 100

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


# Internal state
var _agent: Node2D
var _target_to_give: Node2D
var _amount_to_give: int

enum State { IDLE, GIVING, RECEIVING }
var _state: State = State.IDLE

var _hunger_move_priority: int = 10


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_hunger_timer.wait_time = time_tick
	var stagger_time = randf_range(0.0, 1.0)
	_hunger_timer.start(stagger_time)

	_agent = get_parent() as Node2D

	if is_instance_valid(food_display):
		food_display.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_movement(m: AgentMovement) -> void:
	movement = m


func _on_hunger_timer_timeout() -> void:
	if lose_food:
		food -= 1
		
		if food <= 0:
			food = 0
	
		if food <= hunger_start_threshold:
			if is_instance_valid(food_tasker):
				# Linear interpolation: low priority at threshold, max at min_hunger
				var t = clamp(inverse_lerp(hunger_start_threshold, min_hunger, food), 0.0, 1.0)
				# Default job priority is usually 8. We scale from 8 up to max_hunger_priority.
				var new_priority = lerp(8, max_hunger_priority, t)
				food_tasker.job_priority = int(new_priority)
				food_tasker.request_job()
	
	print(get_parent().name, " ", food)
	_hunger_timer.start(time_tick)


## Command the agent to run to a target and give them the food.
func give_food(target: Node2D, amount: int) -> void:
	if food <= 0 or not is_instance_valid(target) and not _state == State.IDLE:
		return

	if _issue_movement_command(target) or not is_instance_valid(movement):
		_target_to_give = target
		_amount_to_give = amount
		_state = State.GIVING
		_spawn_food()
		_patience_timer.start()
		
	# Check if the target is already within givers radius.
	var current_bodies = get_overlapping_bodies()
	for body in current_bodies:
		if is_instance_valid(_target_to_give) and body == _target_to_give:
			_food_handover()


func _issue_movement_command(target_node: Node2D) -> bool:
	if not is_instance_valid(_agent):
		return false
		
	# Try to find movement component
	if is_instance_valid(movement) and movement.has_method("command_chase_target"):
		if movement.command_chase_target(target_node, _hunger_move_priority):
			return true
	
	return false


func _finish_action() -> void:
	_state = State.IDLE
	_patience_timer.stop()
	_target_to_give = null
	_despawn_food()
	_amount_to_give = 0
	if is_instance_valid(movement):
		movement.clear_movement_order(_hunger_move_priority)


# Food spawns in givers hand and giver runs towards target.
func _spawn_food() -> void:
	if not is_instance_valid(food_display):
		push_warning("HungerHolder: food_display not set on %s, cannot drop food." % _agent.name)
		return
	
	food_display.show()
	food_display.play("spawn")


func _despawn_food() -> void:
	food_display.hide()


# Pass food to target and give them the actual food in amount.
func _food_handover() -> void:
	var actual_amount = min(food, _amount_to_give)
	if actual_amount > 0 and is_instance_valid(_target_to_give.hunger) and _target_to_give.hunger.has_method("receive_food"):
		food -= actual_amount
		_target_to_give.hunger.receive_food(actual_amount)
		
		food_handed.emit()

	_finish_action()


func _on_body_entered(body: Node2D) -> void:
		match _state:
			State.GIVING:
				if is_instance_valid(_target_to_give) and body == _target_to_give:
					_food_handover()
			State.IDLE:
				pass


func receive_food(amount: int) -> void:
	_spawn_food()
	_food_gone_timer.start()
	_state = State.RECEIVING
	
	food += amount


func _on_delivery_patience_timeout() -> void:
	_finish_action()


func _on_food_gone_timeout() -> void:
	_state = State.IDLE
	_despawn_food()
