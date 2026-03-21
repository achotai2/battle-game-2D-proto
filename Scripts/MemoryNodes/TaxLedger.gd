extends Node
class_name TaxLedger

signal request_added
signal request_cleared
signal tax_paid

# requester: Node -> {requester: Node, amount: int, timestamp: int, urgency: float}
var _requests: Dictionary = {}
const EXPIRY_TIME_MS: int = 60000 # 1 minute

var _last_taxed_time: int = 0
var _min_time_between_taxation: Variant = null

func _ready() -> void:
	var agent = ComponentFinder.get_base(self)
	if agent and "current_role" in agent:
		_min_time_between_taxation = UnitRoles.get_min_tax_time(agent.current_role)

func can_be_taxed() -> bool:
	if typeof(_min_time_between_taxation) == TYPE_NIL:
		return false
	if _min_time_between_taxation == 0.0:
		return true

	return (_last_taxed_time == 0 or Time.get_ticks_msec() - _last_taxed_time > (_min_time_between_taxation * 1000.0))

func record_tax_paid() -> void:
	_last_taxed_time = Time.get_ticks_msec()
	tax_paid.emit()

func request_tax(requester: Node, amount: int, urgency: float = 50.0) -> void:
	if not is_instance_valid(requester):
		return

	_requests[requester] = {
		"requester": requester,
		"amount": amount,
		"timestamp": Time.get_ticks_msec(),
		"urgency": urgency
	}
	request_added.emit()

func get_requests() -> Array:
	_cleanup_expired()
	return _requests.values()

func has_request_from(requester: Node) -> bool:
	if not is_instance_valid(requester) or not _requests.has(requester):
		return false

	var req = _requests[requester]
	if Time.get_ticks_msec() - req.timestamp > EXPIRY_TIME_MS:
		_requests.erase(requester)
		return false

	return true

func get_request_amount(requester: Node) -> int:
	if not is_instance_valid(requester) or not _requests.has(requester):
		return 0

	var req = _requests[requester]
	if Time.get_ticks_msec() - req.timestamp > EXPIRY_TIME_MS:
		_requests.erase(requester)
		return 0

	return req.amount

func clear_request(requester: Node) -> void:
	if _requests.has(requester):
		_requests.erase(requester)
		request_cleared.emit()

func _cleanup_expired() -> void:
	var now = Time.get_ticks_msec()
	var keys_to_remove = []
	for requester in _requests:
		if not is_instance_valid(requester) or now - _requests[requester].timestamp > EXPIRY_TIME_MS:
			keys_to_remove.append(requester)

	for requester in keys_to_remove:
		_requests.erase(requester)
