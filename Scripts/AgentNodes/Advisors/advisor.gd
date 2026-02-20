extends Node
class_name Advisor

signal intent_changed

# The brain will assign this agent
var agent: AgentBase = null

# Called by the Brain to get the current intent
func get_intent() -> Intent:
	return null

# Called by the Brain if this advisor's intent was chosen
func enact_intent(intent: Intent) -> void:
	pass

# Called by the Brain when agent is assigned
func initialize() -> void:
	pass
