extends Advisor
class_name AdvisorPlayerInteract

var interactor: PlayerInteractor = null
var movement: AgentMovement = null
var goldWallet: GoldWallet = null
var goldGiver: GoldGiver = null
var _interaction_target: Interactable = null

func _ready() -> void:
	initialize()


func initialize() -> void:
	var base = ComponentFinder.get_base(self)
	if not interactor:
		interactor = base.get("player_interactor")
	if not movement:
		movement = base.get("movement")
	if not goldWallet:
		goldWallet = base.get("gold_wallet")
	if not goldGiver:
		goldGiver = base.get("gold_giver")

	if interactor and not interactor.interaction_started.is_connected(_on_interaction_started):
		interactor.interaction_started.connect(_on_interaction_started)
	if interactor and not interactor.interaction_finished.is_connected(_on_interaction_finished):
		interactor.interaction_finished.connect(_on_interaction_finished)
	if interactor and not interactor.interaction_suspended.is_connected(_on_interaction_suspended):
		interactor.interaction_suspended.connect(_on_interaction_suspended)


func _on_interaction_started(target: Interactable) -> void:
	_interaction_target = target
	intent_changed.emit()


func _on_interaction_finished(target: Interactable) -> void:
	var interaction_cost = target.return_interaction_cost()
	if goldWallet.get_gold() >= interaction_cost:
		goldWallet.subtract_gold(interaction_cost)
		goldGiver.give_gold(ComponentFinder.get_base(target), interaction_cost)
		target.finish_interact(ComponentFinder.get_base(self))
		
	_interaction_target = null
	intent_changed.emit()


func _on_interaction_suspended(target: Interactable) -> void:
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
