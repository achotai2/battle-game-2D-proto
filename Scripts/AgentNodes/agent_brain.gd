extends Node
class_name AgentBrain

@export var agent: AgentBase = null
@export_range(0.1, 2.0, 0.05) var think_interval: float = 0.25

var _think_timer: Timer
var current_advisor: Advisor = null

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
			child.initialize()
			if not child.intent_changed.is_connected(_tick):
				child.intent_changed.connect(_tick)

			var intent = child.get_intent()
			if intent and (best_intent == null or intent.priority > best_intent.priority):
				best_intent = intent

	if best_intent:
		var winner = best_intent.advisor

		# Hand over the wheel if advisor changed
		if winner != current_advisor:
			if current_advisor:
				current_advisor.on_lose_control()

			current_advisor = winner

			if current_advisor:
				current_advisor.on_gain_control()

		# Execute the intent via the advisor who has the wheel
		if current_advisor:
			current_advisor.enact_intent(best_intent)
