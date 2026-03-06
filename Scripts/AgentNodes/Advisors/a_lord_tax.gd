extends Advisor
class_name AdvisorLordTax

var _current_target: Node = null

func get_intent() -> Intent:
	var agent = ComponentFinder.get_base(self)
	if not agent or not is_instance_valid(agent):
		return null

	var castle = agent.return_castle()
	if not castle or not is_instance_valid(castle):
		return null

	var best_minion: Node = null
	var max_gold: int = -1

	var active_minions = castle.get_active_minions()

	# Tie-breaker logic - randomly shuffle so we don't always pick the same one
	var arr = active_minions.duplicate()
	arr.shuffle()

	for minion in arr:
		if not is_instance_valid(minion) or minion == agent:
			continue

		var minion_ledger = ComponentFinder.get_component(minion, "TaxLedger")
		var minion_wallet = ComponentFinder.get_component(minion, "GoldWallet")

		if not minion_ledger or not minion_wallet:
			continue

		if minion_ledger.can_be_taxed() and minion_wallet.get_gold() > 0:
			var gold = minion_wallet.get_gold()
			if gold > max_gold:
				max_gold = gold
				best_minion = minion

	if best_minion and max_gold > 0:
		var intent = Intent.new(100.0, self, Intent.Type.IDLE)
		intent.description = "Taxing Minion"
		intent.target_node = best_minion
		_current_target = best_minion
		return intent

	return null

func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_current_target):
		return

	var target_ledger = ComponentFinder.get_component(_current_target, "TaxLedger")
	var target_wallet = ComponentFinder.get_component(_current_target, "GoldWallet")

	if target_ledger and target_wallet:
		var agent = ComponentFinder.get_base(self)
		if is_instance_valid(agent):
			target_ledger.request_tax(agent, target_wallet.get_gold(), 50.0)

	# Reset target so we can find a new one next tick if possible
	_current_target = null
