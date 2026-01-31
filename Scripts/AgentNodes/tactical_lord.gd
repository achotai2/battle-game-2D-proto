extends Node
class_name TacticalLord

signal chase_target(target: Node2D)
signal move_to_position(pos: Vector2)

@export var wander_radius: float = 300.0
@export var wander_interval: float = 5.0
@export var tax_check_interval: float = 1.0
@export var tax_cooldown: float = 10000.0 # 10 seconds
@export var max_gold_for_guarantee: float = 10.0
@export var movement: AgentMovement = null

var _agent: Node2D = null
var _wander_timer: Timer
var _tax_timer: Timer
var _tax_cooldowns: Dictionary = {} # Node2D -> msec timestamp

func _ready() -> void:
	_wander_timer = Timer.new()
	_wander_timer.wait_time = wander_interval
	_wander_timer.one_shot = true
	_wander_timer.timeout.connect(_on_wander_timeout)
	add_child(_wander_timer)

	_tax_timer = Timer.new()
	_tax_timer.wait_time = tax_check_interval
	_tax_timer.one_shot = false
	_tax_timer.timeout.connect(_on_tax_check)
	add_child(_tax_timer)
	_tax_timer.start()


func set_agent(agent: Node2D) -> void:
	_agent = agent

	# Configure detection to find friendly interactables
	if is_instance_valid(_agent) and "detection" in _agent and is_instance_valid(_agent.detection):
		if _agent.detection.has_method("set_team_filters"):
			_agent.detection.set_team_filters(true, false, false) # Same team, not opposing, not neutral
		_agent.detection.target_kind = AgentTracking.TargetKind.INTERACTABLE
		_agent.detection.refresh()

	_on_wander_timeout() # Start wandering immediately/soon


func set_movement(m: AgentMovement) -> void:
	movement = m


# Standard Tactical Interface (required by AgentBase but maybe unused by Lord)
func set_target(t: Node2D) -> void:
	pass


func clear_target() -> void:
	pass


func detection_refreshed(t: Node2D) -> void:
	pass


func _on_wander_timeout() -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(movement):
		_wander_timer.start(1.0)
		return

	var castle = null
	if _agent.has_method("return_castle"):
		castle = _agent.return_castle()

	if is_instance_valid(castle):
		# Wander around castle
		var random_offset = Vector2.from_angle(randf() * TAU) * (randf() * wander_radius)
		# Assuming castle has global_position
		var target_pos = castle.global_position + random_offset
		movement.command_move_to_position(target_pos, 5)
		move_to_position.emit(target_pos)

	_wander_timer.start(wander_interval + randf() * 2.0)


func _on_tax_check() -> void:
	if not is_instance_valid(_agent) or not "detection" in _agent or not is_instance_valid(_agent.detection):
		return

	var candidates = _agent.detection.get_candidates()
	var now = Time.get_ticks_msec()

	# Cleanup cooldowns
	var to_remove = []
	for minion in _tax_cooldowns:
		if not is_instance_valid(minion) or now > _tax_cooldowns[minion]:
			to_remove.append(minion)
	for m in to_remove:
		_tax_cooldowns.erase(m)

	for minion in candidates:
		if _is_taxable(minion):
			_try_tax(minion)


func _is_taxable(minion: Node2D) -> bool:
	if not is_instance_valid(minion): return false
	if minion == _agent: return false

	# Must be same castle
	if minion.has_method("return_castle") and _agent.has_method("return_castle"):
		if minion.return_castle() != _agent.return_castle():
			return false
	else:
		return false

	# Must NOT be player (already filtered by detection team? No, detection same team includes player)
	if minion.is_in_group("Player"):
		return false

	# Must have GoldHolder with gold > 0
	# Access 'gold' property
	var gold_holder = minion.get("gold")
	if not is_instance_valid(gold_holder):
		return false

	# Access 'gold' amount on GoldHolder
	var amount = gold_holder.get("gold")
	if amount == null or amount <= 0:
		return false

	# Check cooldown
	if _tax_cooldowns.has(minion):
		return false

	return true


func _try_tax(minion: Node2D) -> void:
	var gold_holder = minion.get("gold")
	var gold_amount = gold_holder.get("gold")
	var probability = clamp(float(gold_amount) / max_gold_for_guarantee, 0.0, 1.0)

	if randf() < probability:
		# Tax!
		if gold_holder.has_method("give_gold"):
			gold_holder.give_gold(_agent, 1)
			_tax_cooldowns[minion] = Time.get_ticks_msec() + tax_cooldown
