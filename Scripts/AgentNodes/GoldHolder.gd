extends Area3D
class_name GoldHolder

signal goldChanged(amount_of_gold: int)

## Current amount of gold held.
@export var gold: int = 0:
	set(v):
		gold = max(0, v)

## The scene used to represent gold on the ground when dropped.
@export var gold_display: AnimatedSprite3D

## Connects to the agents move node to call commands to it.
@export var movement: AgentMovement

## Priority for the movement command.
@export var movement_priority: int = 5

## How long will agent try to deliver gold before giving up.
@export var _patience_timer: Timer = null

## Time gold stays in hand after received before despawning, for visual purposes only.
@export var _gold_gone_timer: Timer = null

## When can I be taxed again after Lord has taxed me.
@export var _tax_timer: Timer = null

# Internal state
var _agent: CharacterBody3D
var _target_to_give: CharacterBody3D
var _amount_to_give: int

enum State { IDLE, GIVING, RECEIVING }
var _state: State = State.IDLE


func _ready() -> void:
	_agent = get_parent() as CharacterBody3D

	if is_instance_valid(gold_display):
		gold_display.hide()

	if not is_instance_valid(_patience_timer):
		_patience_timer = Timer.new()
		_patience_timer.wait_time = 5.0
		_patience_timer.one_shot = true
		add_child(_patience_timer)

	if not _patience_timer.timeout.is_connected(_on_delivery_patience_timeout):
		_patience_timer.timeout.connect(_on_delivery_patience_timeout)

	if not is_instance_valid(_gold_gone_timer):
		_gold_gone_timer = Timer.new()
		_gold_gone_timer.wait_time = 2.0
		_gold_gone_timer.one_shot = true
		add_child(_gold_gone_timer)

	if not _gold_gone_timer.timeout.is_connected(_on_gold_gone_timeout):
		_gold_gone_timer.timeout.connect(_on_gold_gone_timeout)

	if not is_instance_valid(_tax_timer):
		_tax_timer = Timer.new()
		_tax_timer.wait_time = 10.0
		_tax_timer.one_shot = true
		add_child(_tax_timer)

	# Sent to update the UI display for player gold amount.
	call_deferred("_change_gold_amount", 0)


## Command the agent to run to a target and give them the gold.
func give_gold(target: CharacterBody3D, amount: int) -> void:
	if gold <= 0 or not is_instance_valid(target) and not _state == State.IDLE:
		return

	_target_to_give = target
	_amount_to_give = amount
	_state = State.GIVING
	_spawn_gold()
	_patience_timer.start()
		
	# Check if the target is already within givers radius.
	var current_bodies = get_overlapping_bodies()
	for body in current_bodies:
		if is_instance_valid(_target_to_give) and body == _target_to_give:
			_gold_handover()

	if not _issue_movement_command(target) and not is_instance_valid(movement):
		_gold_handover()


func _issue_movement_command(target_node: CharacterBody3D) -> bool:
	if not is_instance_valid(_agent):
		return false
		
	# Try to find movement component
	if is_instance_valid(movement) and movement.has_method("command_chase_target"):
		if movement.command_chase_target(target_node, movement_priority):
			return true
	
	return false


func _finish_action() -> void:
	_state = State.IDLE
	_patience_timer.stop()
	_target_to_give = null
	_despawn_gold()
	_amount_to_give = 0
	if is_instance_valid(movement):
		movement.clear_movement_order(movement_priority)


# Gold spawns in givers hand and giver runs towards target.
func _spawn_gold() -> void:
	if not is_instance_valid(gold_display):
		push_warning("GoldHolder: gold_display not set on %s, cannot drop gold." % _agent.name)
		return
	
	gold_display.show()
	gold_display.play("spawn")


func _despawn_gold() -> void:
	gold_display.hide()


# Pass gold to target and give them the actual gold in amount.
func _gold_handover() -> void:
	var actual_amount = min(gold, _amount_to_give)
	if actual_amount > 0 and is_instance_valid(_target_to_give.gold) and _target_to_give.gold.has_method("receive_gold"):
		_change_gold_amount(-1 * actual_amount)
		_target_to_give.gold.receive_gold(actual_amount)

	_finish_action()


func _on_body_entered(body: Node3D) -> void:
		match _state:
			State.GIVING:
				if is_instance_valid(_target_to_give) and body == _target_to_give:
					_gold_handover()
			State.IDLE:
				pass


func receive_gold(amount: int) -> void:
	_spawn_gold()
	_gold_gone_timer.start()
	_state = State.RECEIVING
	
	_change_gold_amount(amount)


func _on_delivery_patience_timeout() -> void:
	# Just teleport them the gold.
	_gold_handover()


func _on_gold_gone_timeout() -> void:
	_state = State.IDLE
	_despawn_gold()


func set_movement(m: AgentMovement) -> void:
	movement = m


func _change_gold_amount(amount: int) -> void:
	gold += amount
	goldChanged.emit(gold)


func can_i_tax_you(lord: CharacterBody3D) -> void:
	# Must NOT be player (already filtered by detection team? No, detection same team includes player)
	if get_parent().is_in_group("Player"):
		return

	if not _tax_timer.is_stopped():
		return

	# Max probability of being taxed when 10.0 gold. Increases linearly to then.
	var probability = clamp(float(gold) / 10.0, 0.0, 1.0)

	if randf() < probability:
		# Tax!
		give_gold(lord, 1)
		_tax_timer.start()
