extends Advisor
class_name AdvisorPlayer

@onready var controls = %PlayerControls
@onready var movement = %AgentMovement


func _ready() -> void:
	if not controls.input_changed.is_connected(_on_input_changed):
		controls.input_changed.connect(_on_input_changed)


func get_intent() -> Intent:
	if not agent.controls: return null

	var dir = controls.get_input_vector()

	# Deadzone control feature, for joysticks.
	if dir.length_squared() > 0.01:
		var intent = Intent.new(100.0, self, Intent.Type.PLAYER_MOVE)
		intent.direction = dir
		intent.description = "Player Input Move"
		return intent

	# Fallback to IDLE so other advisors (like Attack) can take over
	return Intent.new(1.0, self, Intent.Type.IDLE)


func _on_input_changed() -> void:
	intent_changed.emit()


func enact_intent(intent: Intent) -> void:
	if not movement: return

	if intent.type == Intent.Type.PLAYER_MOVE:
		movement.command_player_direction(intent.direction)
		
	elif intent.type == Intent.Type.IDLE:
		movement.clear_movement_order()
