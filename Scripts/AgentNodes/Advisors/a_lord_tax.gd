extends Advisor
class_name AdvisorLordTax

var _current_target: Node = null
var _agent: AgentBase = null
var _currentLedger: TaxLedger = null
var _currentWallet: GoldWallet = null
var _tax_requested: bool = false # Prevents spamming the request_tax function

func initialize() -> void:
	if not _agent:
		_agent = ComponentFinder.get_base(self)


func get_intent() -> Intent:
	if not _agent:
		return null

	# --- 1. VALIDATE CURRENT TARGET ---
	if is_instance_valid(_current_target) and is_instance_valid(_currentLedger) and is_instance_valid(_currentWallet):
		# How do we know they are still valid? 
		# - They haven't died (is_instance_valid)
		# - They still have money to give
		# - They are still eligible to be taxed (If they paid, can_be_taxed() should return false due to a cooldown)
		if _currentWallet.get_gold() > 0 and _currentLedger.can_be_taxed():
			var intent = Intent.new(100.0, self, Intent.Type.IDLE)
			intent.description = "Waiting for Tax from " + _current_target.name
			intent.target_node = _current_target
			return intent
		else:
			# They paid us, went broke, or became immune. Time to move on.
			_clear_target()

	# --- 2. FIND A NEW TARGET ---
	var _castle = _agent.return_castle()
	if not _castle:
		return null

	var best_minion: Node = null
	var max_gold: int = -1

	var active_minions = _castle.get_active_minions()

	# Tie-breaker logic
	var arr = active_minions.duplicate()
	arr.shuffle()

	for minion in arr:
		if not is_instance_valid(minion) or minion == _agent:
			continue

		var minion_ledger: TaxLedger = ComponentFinder.get_component(minion, "TaxLedger")
		var minion_wallet: GoldWallet = ComponentFinder.get_component(minion, "GoldWallet")

		if not minion_ledger or not minion_wallet:
			continue

		if minion_ledger.can_be_taxed() and minion_wallet.get_gold() > 0:
			var gold = minion_wallet.get_gold()
			if gold > max_gold:
				max_gold = gold
				best_minion = minion
				_currentLedger = minion_ledger
				_currentWallet = minion_wallet

	if best_minion and max_gold > 0:
		var intent = Intent.new(100.0, self, Intent.Type.IDLE)
		intent.description = "Taxing Minion"
		intent.target_node = best_minion
		_current_target = best_minion
		_tax_requested = false # Reset the flag so we can ping them!
		return intent

	return null


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_current_target):
		return

	# Only send the request once! Then just wait.
	if _currentLedger and _currentWallet and not _tax_requested:
		var agent = ComponentFinder.get_base(self)
		if is_instance_valid(agent):
			_currentLedger.request_tax(agent, 1, 50.0)
			_tax_requested = true


func _clear_target() -> void:
	_current_target = null
	_currentLedger = null
	_currentWallet = null
	_tax_requested = false
