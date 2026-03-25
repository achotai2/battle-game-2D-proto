extends Advisor
class_name AdvisorPlayerInteract

var interactor: Node = null
var movement: AgentMovement = null
var goldWallet: Node = null
var goldGiver: Node = null

var _interaction_target: Node3D = null


func initialize() -> void:
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		interactor = _agent.get("player_interactor")
		movement = _agent.get("movement")
		goldWallet = _agent.get("gold_wallet")
		goldGiver = _agent.get("gold_giver")

		# 3. Connect to purely discrete interaction signals
		if is_instance_valid(interactor):
			if not interactor.interaction_started.is_connected(_on_interaction_started):
				interactor.interaction_started.connect(_on_interaction_started)
			if not interactor.interaction_finished.is_connected(_on_interaction_finished):
				interactor.interaction_finished.connect(_on_interaction_finished)
			if not interactor.interaction_suspended.is_connected(_on_interaction_suspended):
				interactor.interaction_suspended.connect(_on_interaction_suspended)


# --- EVENT TRIGGERS ---

func _on_interaction_started(target: Node3D) -> void:
	_interaction_target = target
	request_intent_update()


func _on_interaction_finished(target: Node3D) -> void:
	var interaction_cost = 0
	if target.has_method("return_interaction_cost"):
		interaction_cost = target.return_interaction_cost()
		
	var can_afford = true
	
	# --- 1. HANDLE PAYMENT (If it costs anything) ---
	if interaction_cost > 0:
		if is_instance_valid(goldWallet) and goldWallet.has_method("get_gold"):
			if goldWallet.get_gold() >= interaction_cost:
				# We have the money! Spend it.
				goldWallet.subtract_gold(interaction_cost)
				
				# Optional: Use GoldGiver if the player actually has one
				if is_instance_valid(goldGiver) and goldGiver.has_method("give_gold"):
					var target_base = _find_root_base(target)
					if is_instance_valid(target_base):
						goldGiver.give_gold(target_base, interaction_cost)
			else:
				can_afford = false # Broke!
				print("Player Interact: Not enough gold! Cost: ", interaction_cost)
		else:
			can_afford = false # No wallet to pay with!
			push_warning("Player Interact: Target costs gold, but Player has no Wallet!")

	# --- 2. FINISH INTERACTION ---
	if can_afford:
		if target.has_method("finish_interact"):
			target.finish_interact(_agent)
	
	# 3. Clean up the state
	_interaction_target = null
	request_intent_update()


func _on_interaction_suspended(_target: Node3D) -> void:
	_interaction_target = null
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(interactor) or not is_instance_valid(_interaction_target):
		return null

	var intent = Intent.new(100.0, self, Intent.Type.PLAYER_INTERACT)
	intent.target_node = _interaction_target
	intent.description = "Player interacting with " + _interaction_target.name
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent): return

	if is_instance_valid(movement):
		movement.stop()

	var animate = _agent.get("animate")
	if is_instance_valid(animate):
		if is_instance_valid(intent.target_node) and animate.has_method("face_target"):
			animate.face_target(intent.target_node.global_position)
			
		if animate.has_method("play_work"):
			animate.play_work()


func on_lose_control() -> void:
	if is_instance_valid(_interaction_target):
		if is_instance_valid(interactor) and interactor.has_method("suspend_interaction"):
			interactor.suspend_interaction()
			
	_interaction_target = null


# --- HELPERS ---

# Replaced ComponentFinder with the safe hierarchy loop!
func _find_root_base(start_node: Node) -> Node:
	var current = start_node
	while current and current != start_node.get_tree().root:
		if current is AgentBase or current.has_method("return_castle"):
			return current
		current = current.get_parent()
	return null
