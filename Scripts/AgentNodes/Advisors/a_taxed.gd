extends Advisor
class_name AdvisorTaxed

var _gold_wallet: GoldWallet = null
var _tax_ledger: TaxLedger = null
var _gold_giver: GoldGiver = null
var unit_speed: UnitSpeed = null
var agent: AgentBase = null
var movement: AgentMovement = null

# Cached request we are currently fulfilling
var _current_requester: Node = null


func _ready() -> void:
	# Components should be children of agent, but might be under Memory/Sensors/Brain/Motors
	# We can't guarantee they are ready here if they are siblings.
	# Better to find them on demand or in first get_intent.
	pass


func _find_components() -> bool:
	if not agent:
		agent = ComponentFinder.get_base(self)
	if not movement:
		movement = agent.get("movement")
	if not _gold_wallet:
		_gold_wallet = agent.get("gold_wallet")
	if not _tax_ledger:
		_tax_ledger = agent.get("tax_ledger")
	if not _gold_giver:
		_gold_giver = agent.get("gold_giver")
	if not unit_speed:
		unit_speed = agent.get("unit_speed")

	return agent and movement and _gold_wallet and _tax_ledger and _gold_giver and unit_speed


func get_intent() -> Intent:
	if not _find_components():
		return null

	var requests = _tax_ledger.get_requests()
	if requests.is_empty():
		return null

	# Pick the first request
	var req = requests[0]
	if not is_instance_valid(req.requester):
		_tax_ledger.clear_request(req.requester) # Should have been cleaned up but just in case
		return null

	_current_requester = req.requester

	var urgency = 15.0
	if req.has("urgency"):
		urgency = req.urgency

	var intent = Intent.new(urgency, self, Intent.Type.MOVE) # Higher than work (5.0)
	intent.description = "Paying Taxes"
	intent.target_position = req.requester.global_position
	intent.target_node = req.requester
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_current_requester):
		return

	# Move
	if unit_speed:
		movement.max_speed = unit_speed.run_speed
	if movement:
		movement.move_to_position(_current_requester.global_position)

	# Check range
	# Assuming range is close enough for interaction, e.g., 2-3 meters.
	var dist_sq = get_distance_squared_to(_current_requester)
	if dist_sq <= 9.0: # 3 meters
		var amount = _tax_ledger.get_request_amount(_current_requester)
		# We attempt to give all requested, or what we have?
		# Ledger says "for how much".
		# GoldGiver handles check.

		# If we don't have enough, we give what we have?
		# GoldGiver.give_gold fails if we don't have enough.
		# Maybe we should give min(amount, current_gold)?
		var amount_to_give = min(amount, _gold_wallet.get_gold())

		if amount_to_give > 0:
			if _gold_giver.give_gold(_current_requester, amount_to_give):
				# Success
				_gold_wallet.subtract_gold(amount_to_give)
				_tax_ledger.record_tax_paid()

		# Regardless of success (maybe we have 0 gold), we clear the request so we don't get stuck in loop
		# Or maybe we only clear if we paid full?
		# The prompt says: "TaxLedger... keeps these tax requests in a ledger for a certain period of time... before it forgets about it."
		# If we tried and failed, maybe we should forget it or try again later?
		# If we remove it, we stop trying.
		_tax_ledger.clear_request(_current_requester)
		_current_requester = null

		if movement:
			movement.stop()


func get_distance_squared_to(target: Node3D) -> float:
	if not is_instance_valid(agent) or not is_instance_valid(target):
		return INF

	return agent.global_position.distance_squared_to(target.global_position)
