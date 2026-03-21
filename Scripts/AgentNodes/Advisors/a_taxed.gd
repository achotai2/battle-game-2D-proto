extends Advisor
class_name AdvisorTaxed

var _agent: AgentBase = null
var _gold_wallet: Node = null
var _tax_ledger: Node = null
var _gold_giver: Node = null
var movement: AgentMovement = null
var unit_speed: Node = null
var animate: Node = null

# Cached target
var _current_requester: Node3D = null


func initialize() -> void:
	# 1. Safely grab the root agent once
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)
		
	if is_instance_valid(_agent):
		# 2. Grab all components directly
		movement = _agent.get("movement")
		_gold_wallet = _agent.get("gold_wallet")
		_tax_ledger = _agent.get("tax_ledger")
		_gold_giver = _agent.get("gold_giver")
		unit_speed = _agent.get("unit_speed")
		animate = _agent.get("animate")

		# 3. Connect to purely Discrete Ledger signals!
		if is_instance_valid(_tax_ledger):
			if _tax_ledger.has_signal("request_added") and not _tax_ledger.request_added.is_connected(_on_request_added):
				_tax_ledger.request_added.connect(_on_request_added)
			if _tax_ledger.has_signal("request_cleared") and not _tax_ledger.request_cleared.is_connected(_on_request_cleared):
				_tax_ledger.request_cleared.connect(_on_request_cleared)


# --- EVENT TRIGGERS ---

func _on_request_added() -> void:
	request_intent_update()


func _on_request_cleared() -> void:
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_tax_ledger):
		return null

	var requests = []
	if _tax_ledger.has_method("get_requests"):
		requests = _tax_ledger.get_requests()
		
	if requests.is_empty():
		_current_requester = null
		return null

	# Pick the first request
	var req = requests[0]
	if not is_instance_valid(req.requester):
		if _tax_ledger.has_method("clear_request"):
			_tax_ledger.clear_request(req.requester)
		return null

	_current_requester = req.requester

	# Grab the urgency (Defaults to 15.0, overriding Goblin March (10) but lower than Fleeing (30))
	var urgency = 15.0
	if req.has("urgency"):
		urgency = req.urgency

	var intent = Intent.new(urgency, self, Intent.Type.MOVE)
	intent.description = "Paying Taxes to " + req.requester.name
	intent.target_node = req.requester
	intent.target_vector = req.requester.global_position
	
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(_current_requester):
		return

	# 1. Check distance continuously in the physics frame
	var dist_sq = _agent.global_position.distance_squared_to(_current_requester.global_position)
	
	if dist_sq > 9.0: # Further than 3 meters
		if is_instance_valid(unit_speed) and is_instance_valid(movement):
			movement.max_speed = unit_speed.run_speed
			movement.move_to_position(_current_requester.global_position)
			
	else: # Within 3 meters! Time to pay up.
		# Stop walking and face the Lord
		if is_instance_valid(movement):
			movement.stop()
			
		if is_instance_valid(animate):
			if animate.has_method("face_target"):
				animate.face_target(_current_requester.global_position)
			if animate.has_method("play_work"):
				animate.play_work() # Visual feedback for handing over gold

		# Execute Transaction Logic
		if is_instance_valid(_tax_ledger) and is_instance_valid(_gold_wallet) and is_instance_valid(_gold_giver):
			var amount = 0
			if _tax_ledger.has_method("get_request_amount"):
				amount = _tax_ledger.get_request_amount(_current_requester)
				
			var amount_to_give = min(amount, _gold_wallet.get_gold())

			if amount_to_give > 0:
				if _gold_giver.has_method("give_gold") and _gold_giver.give_gold(_current_requester, amount_to_give):
					_gold_wallet.subtract_gold(amount_to_give)
					if _tax_ledger.has_method("record_tax_paid"):
						_tax_ledger.record_tax_paid()

			# Clear the request (This will automatically emit `request_cleared` and put this Advisor to sleep!)
			if _tax_ledger.has_method("clear_request"):
				_tax_ledger.clear_request(_current_requester)
				
		_current_requester = null


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
