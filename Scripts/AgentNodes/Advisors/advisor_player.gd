extends Advisor
class_name AdvisorPlayer

func initialize() -> void:
	if agent and agent.controls:
		if not agent.controls.input_changed.is_connected(_on_input_changed):
			agent.controls.input_changed.connect(_on_input_changed)

func get_intent() -> Intent:
	if not agent or not agent.controls: return null

	var controls = agent.controls
	var dir = controls.get_input_vector()

	if dir.length_squared() > 0.01:
		var intent = Intent.new(100.0, self, Intent.Type.PLAYER_MOVE)
		intent.direction = dir
		intent.description = "Player Input Move"
		return intent

	# Fallback to IDLE so other advisors (like Attack) can take over
	return Intent.new(1.0, self, Intent.Type.IDLE)

func _on_input_changed() -> void:
	intent_changed.emit()
