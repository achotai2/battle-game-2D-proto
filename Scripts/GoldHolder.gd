extends Area2D
class_name GoldHolder

## Current amount of gold held.
@export var gold: int = 0:
	set(v):
		gold = max(0, v)

## The scene used to represent gold on the ground when dropped.
@export var gold_scene: PackedScene

## Connects to the agents move node to call commands to it.
@export var movement: AgentMovement

## Priority for the movement command.
@export var movement_priority: int = 5

## How long will agent try to deliver gold before giving up.
@export var _patience_timer: Timer = null

## Time gold stays in hand after received before despawning, for visual purposes only.
@export var _gold_gone_timer: Timer = null

# Internal state
var _agent: Node2D
var _target_to_give: Node2D
var _amount_to_give: int
var _gold_child: Node2D

enum State { IDLE, GIVING }
var _state: State = State.IDLE


func _ready() -> void:
	_agent = get_parent() as Node2D


## Command the agent to run to a target and give them the gold.
func give_gold(target: Node2D, amount: int) -> void:
	if gold <= 0 or not is_instance_valid(target) and not _state == State.IDLE:
		return

	if _issue_movement_command(target):
		_target_to_give = target
		_amount_to_give = amount
		_state = State.GIVING
		_spawn_gold(amount)
		_patience_timer.start()


func _issue_movement_command(target_node: Node2D) -> bool:
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
func _spawn_gold(amount: int) -> void:
	if not gold_scene:
		push_warning("GoldHolder: gold_scene not set on %s, cannot drop gold." % _agent.name)
		return
		
	var g = gold_scene.instantiate()
	if g.has_method("set_amount"):
		g.set_amount(amount)
	
	# Add to the world
	_gold_child = g
	_agent.add_child(g)
	# Position it slightly offset from the agent
	var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	g.global_position = _agent.global_position + offset


func _despawn_gold() -> void:
	if is_instance_valid(_gold_child):
		_gold_child.queue_free()
		_gold_child = null


# Pass gold to target and give them the actual gold in amount.
func _gold_handover() -> void:
	var actual_amount = min(gold, _amount_to_give)
	if actual_amount > 0 and is_instance_valid(_target_to_give.gold) and _target_to_give.gold.has_method("receive_gold"):
		gold -= actual_amount
		_target_to_give.gold.receive_gold(actual_amount)

	_finish_action()


func _on_body_entered(body: Node2D) -> void:
		match _state:
			State.GIVING:
				if is_instance_valid(_target_to_give) and body == _target_to_give:
					_gold_handover()
			State.IDLE:
				pass


func receive_gold(amount: int) -> void:
	_spawn_gold(0)
	_gold_gone_timer.start()
	
	gold += amount


func _on_delivery_patience_timeout() -> void:
	_finish_action()


func _on_gold_gone_timeout() -> void:
	_despawn_gold()


func set_movement(m: AgentMovement) -> void:
	movement = m
