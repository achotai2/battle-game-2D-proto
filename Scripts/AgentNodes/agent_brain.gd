extends Node
class_name AgentBrain

@export var agent: AgentBase = null

var current_advisor: Advisor = null
var current_intent: Intent = null

# The shield against infinite loops!
var _evaluation_queued: bool = false 


func _ready() -> void:
	pass

func deactivate() -> void:
	pass

func activate() -> void:
	if not is_instance_valid(agent):
		agent = _find_root_base(self)

	# We initialize and connect everything exactly ONCE
	refresh_advisors()


func _physics_process(_delta: float) -> void:
	# ENACTMENT PHASE: Runs smoothly every frame
	# Because your Advisors are optimized to use explicit API calls and _is_playing_action() locks,
	# running this every frame is extremely cheap and makes combat/movement highly responsive!
	if current_advisor and current_intent:
		current_advisor.enact_intent(current_intent)


# We now accept the 'passed_agent' from the _deferred_apply_role call
func refresh_advisors(passed_agent: AgentBase = null) -> void:
	# 1. Secure the Agent Reference
	if is_instance_valid(passed_agent):
		agent = passed_agent
	elif not is_instance_valid(agent):
		agent = _find_root_base(self)
		
	# 2. Hand it down to the kids!
	for child in get_children():
		if child is Advisor:
			# INJECT THE DEPENDENCY: 
			# We force the reference into the child before initializing it.
			child.set_agent(self.agent)
				
			# (If your Advisor's initialize function expects the agent as an argument, 
			# you can change this to: child.initialize(self.agent) )
			child.initialize()
			
			# Wire up the new queue system
			if not child.intent_changed.is_connected(_queue_evaluation):
				child.intent_changed.connect(_queue_evaluation)

	# Force an initial evaluation so the unit knows what to do on spawn
	_queue_evaluation()


func _queue_evaluation() -> void:
	# THE MAGIC BULLET FOR INFINITE LOOPS:
	# If multiple advisors raise their dirty flags in the same frame, 
	# we only schedule ONE evaluation at the very end of the physics frame.
	if not _evaluation_queued:
		_evaluation_queued = true
		call_deferred("_evaluate_intents")


func _evaluate_intents() -> void:
	if not is_instance_valid(agent): return
	
	# Reset the queue flag so we can accept new updates next frame
	_evaluation_queued = false

	var best_intent: Intent = null

	# 1. EVALUATION PHASE: Ask everyone for their cached intent
	# This is virtually free on the CPU because Jules' dirty flags prevent math recalculations!
	for child in get_children():
		if child is Advisor:
			var intent = child.get_intent()
			
			if intent:
				# If this is the first valid intent, or it beats the current best priority
				if best_intent == null or intent.priority > best_intent.priority:
					best_intent = intent

	# 2. HANDOVER PHASE: Give the wheel to the winner
	if best_intent:
		var winner = best_intent.advisor

		if winner != current_advisor:
			if is_instance_valid(current_advisor) and current_advisor.has_method("on_lose_control"):
				current_advisor.on_lose_control()

			current_advisor = winner

			if is_instance_valid(current_advisor) and current_advisor.has_method("on_gain_control"):
				current_advisor.on_gain_control()

		# Always update the intent, even if the advisor stayed the same (e.g., chasing a new target)
		current_intent = best_intent
		
	else:
		# Fallback: Nobody knows what to do
		if is_instance_valid(current_advisor) and current_advisor.has_method("on_lose_control"):
			current_advisor.on_lose_control()
		current_advisor = null
		current_intent = null


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
