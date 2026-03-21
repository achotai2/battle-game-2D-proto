extends Node
class_name Advisor

signal intent_changed

var _current_intent: Intent = null
var _intent_needs_update: bool = true
var _agent: AgentBase = null


# Called by the Brain to get the current intent
func get_intent() -> Intent:
	if _intent_needs_update:
		_current_intent = _calculate_intent()
		_intent_needs_update = false
	return _current_intent

func _calculate_intent() -> Intent:
	return null

func request_intent_update() -> void:
	_intent_needs_update = true
	intent_changed.emit()

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


func set_agent(newAgent: Node) -> void:
	_agent = newAgent
