extends Advisor
class_name AdvisorLordTax

# --- CONFIGURATION ---
@export var tax_check_interval: float = 2.0 # Slightly slower poll saves massive CPU in big kingdoms

var _current_target: Node = null
var _currentLedger: Node = null # Weak typed in case the class isn't loaded globally
var _currentWallet: Node = null

var _tax_requested: bool = false
var _economy_timer: Timer = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	# 2. Setup the Macro-Economy Polling Timer
	if not is_instance_valid(_economy_timer):
		_economy_timer = Timer.new()
		_economy_timer.wait_time = tax_check_interval
		_economy_timer.autostart = true
		_economy_timer.timeout.connect(request_intent_update)
		add_child(_economy_timer)


func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent):
		return null

	# --- 1. VALIDATE CURRENT TARGET ---
	if is_instance_valid(_current_target) and is_instance_valid(_currentLedger) and is_instance_valid(_currentWallet):
		if _currentWallet.get_gold() > 0 and _currentLedger.can_be_taxed():
			var intent = Intent.new(100.0, self, Intent.Type.IDLE)
			intent.description = "Waiting for Tax from " + _current_target.name
			intent.target_node = _current_target
			return intent
		else:
			# They paid us, went broke, or became immune. Time to move on.
			_clear_target()

	# --- 2. FIND A NEW TARGET ---
	var castle = _agent.return_castle()
	if not is_instance_valid(castle) or not castle.has_method("get_active_minions"):
		return null

	var best_minion: Node = null
	var max_gold: int = -1

	var active_minions = castle.get_active_minions()
	
	# Tie-breaker logic (shuffling ensures we don't always target the same peasant first if gold is tied)
	var arr = active_minions.duplicate()
	arr.shuffle()

	for minion in arr:
		if not is_instance_valid(minion) or minion == _agent:
			continue

		var minion_ledger = minion.get("tax_ledger")
		var minion_wallet = minion.get("gold_wallet")

		if not is_instance_valid(minion_ledger) or not is_instance_valid(minion_wallet):
			continue

		if minion_ledger.has_method("can_be_taxed") and minion_ledger.can_be_taxed():
			var gold = minion_wallet.get_gold()
			if gold > 0 and gold > max_gold:
				max_gold = gold
				best_minion = minion
				_currentLedger = minion_ledger
				_currentWallet = minion_wallet

	# --- 3. LOCK IN THE TARGET ---
	if is_instance_valid(best_minion) and max_gold > 0:
		var intent = Intent.new(100.0, self, Intent.Type.IDLE)
		intent.description = "Taxing " + best_minion.name
		intent.target_node = best_minion
		
		_current_target = best_minion
		_tax_requested = false # Reset the flag so we can ping them!
		
		return intent

	return null


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(_current_target):
		return

	# Explicit Movement: Stop walking!
	var movement = _agent.get("movement")
	if is_instance_valid(movement) and movement.has_method("stop"):
		movement.stop()

	# Explicit Animation: Face the peasant we are robbing and stand idle
	var animate = _agent.get("animate")
	if is_instance_valid(animate):
		if animate.has_method("face_target"):
			animate.face_target(_current_target.global_position)
		if animate.has_method("play_idle"):
			animate.play_idle()

	# Only send the request once! Then just wait.
	if is_instance_valid(_currentLedger) and not _tax_requested:
		if _currentLedger.has_method("request_tax"):
			_currentLedger.request_tax(_agent, 1, 50.0)
			_tax_requested = true


func _clear_target() -> void:
	_current_target = null
	_currentLedger = null
	_currentWallet = null
	_tax_requested = false


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
