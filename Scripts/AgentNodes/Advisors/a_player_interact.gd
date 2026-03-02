extends Advisor
class_name AdvisorPlayerInteract

var interactor: PlayerInteractor = null
var movement: AgentMovement = null
var _interaction_target: Node3D = null

func _ready() -> void:
	initialize()


func initialize() -> void:
	if not interactor:
		interactor = ComponentFinder.get_component(self, "PlayerInteractor")
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")
	
	if interactor and not interactor.interaction_started.is_connected(_on_interaction_started):
		interactor.interaction_started.connect(_on_interaction_started)
	if interactor and not interactor.interaction_finished.is_connected(_on_interaction_ended):
		interactor.interaction_finished.connect(_on_interaction_ended)
	if interactor and not interactor.interaction_suspended.is_connected(_on_interaction_ended):
		interactor.interaction_suspended.connect(_on_interaction_ended)


func _on_interaction_started(target: Node3D) -> void:
	_interaction_target = target
	intent_changed.emit()


func _on_interaction_ended(target: Node3D) -> void:
	_interaction_target = null
	intent_changed.emit()


func get_intent() -> Intent:
	if not interactor: return null

	# Deadzone control feature, for joysticks.
	if is_instance_valid(_interaction_target):
		var intent = Intent.new(100.0, self, Intent.Type.PLAYER_INTERACT)
		intent.direction = Vector3.ZERO
		intent.description = "Player Input Interaction"
		return intent

	# Fallback to IDLE so other advisors (like Attack) can take over
	return Intent.new(1.0, self, Intent.Type.IDLE)


func enact_intent(intent: Intent) -> void:
	if not movement: return
	movement.stop()


func on_lose_control() -> void:
	pass
