extends Node
class_name Advisor

signal intent_changed

# The brain will assign this agent
var agent: AgentBase = null

# Stores references to motor scripts keyed by name
var motors: Dictionary = {}

# Called by the Brain to get the current intent
func get_intent() -> Intent:
	return null

# Called by the Brain if this advisor's intent was chosen
func enact_intent(intent: Intent) -> void:
	pass

# Called by the Brain when agent is assigned
func initialize() -> void:
	motors.clear()
	if agent and is_instance_valid(agent):
		var motor_node = agent.get_node_or_null("Motor")
		if motor_node:
			for child in motor_node.get_children():
				if child is Node:
					motors[child.name] = child

# Called when this advisor takes control of the agent
func on_gain_control() -> void:
	pass
	# print("Advisor ", name, " gained control.")

# Called when this advisor loses control of the agent
func on_lose_control() -> void:
	# print("Advisor ", name, " lost control.")
	if agent and agent.movement:
		# Stop movement when losing control
		agent.movement.stop()
