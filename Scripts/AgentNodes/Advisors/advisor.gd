extends Node
class_name Advisor

signal intent_changed

# Called by the Brain to get the current intent
func get_intent() -> Intent:
	return null

# Called by the Brain if this advisor's intent was chosen
func enact_intent(intent: Intent) -> void:
	pass

# Called by the Brain when agent is assigned
func initialize() -> void:
	pass

# Called when this advisor takes control of the agent
func on_gain_control() -> void:
	pass
	# print("Advisor ", name, " gained control.")

# Called when this advisor loses control of the agent
func on_lose_control() -> void:
	pass
