extends Node
class_name AgentBrain

@export var agent: AgentBase = null
@export_range(0.1, 2.0, 0.1) var think_interval: float = 0.25

var _think_timer: Timer

func _ready() -> void:
	_think_timer = Timer.new()
	_think_timer.wait_time = think_interval
	_think_timer.autostart = true
	_think_timer.timeout.connect(_tick)
	add_child(_think_timer)

	# Stagger start to avoid spikes
	_think_timer.start(randf() * think_interval)

	# Connect to existing advisors
	for child in get_children():
		if child is Advisor:
			child.intent_changed.connect(_tick)

func _tick() -> void:
	if not agent or not is_instance_valid(agent): return

	var best_intent: Intent = null

	for child in get_children():
		if child is Advisor:
			# Ensure advisor has agent reference
			if child.agent == null:
				child.agent = agent
				child.initialize()
				if not child.intent_changed.is_connected(_tick):
					child.intent_changed.connect(_tick)

			var intent = child.get_intent()
			if intent and (best_intent == null or intent.priority > best_intent.priority):
				best_intent = intent

	if best_intent:
		_execute_intent(best_intent)
		if best_intent.advisor:
			best_intent.advisor.enact_intent(best_intent)

func _execute_intent(intent: Intent) -> void:
	var movement = agent.movement
	if not movement: return

	# We use a high priority to override any lingering internal states,
	# but rely on the Brain to keep issuing commands.
	var cmd_priority = 10

	match intent.type:
		Intent.Type.IDLE:
			movement.clear_movement_order(cmd_priority)

		Intent.Type.MOVE:
			movement.command_move_to_position(intent.target_position, cmd_priority)

		Intent.Type.CHASE:
			if is_instance_valid(intent.target_node):
				movement.command_chase_target(intent.target_node, cmd_priority)
			else:
				movement.clear_movement_order(cmd_priority)

		Intent.Type.ATTACK:
			if is_instance_valid(intent.target_node):
				movement.command_start_attack(intent.target_node, cmd_priority)
			else:
				movement.clear_movement_order(cmd_priority)

		Intent.Type.WORK:
			movement.command_start_work(cmd_priority)

		Intent.Type.FLEE:
			movement.command_move_to_position(intent.target_position, cmd_priority)

		Intent.Type.PLAYER_MOVE:
			movement.command_player_direction(intent.direction, cmd_priority)
