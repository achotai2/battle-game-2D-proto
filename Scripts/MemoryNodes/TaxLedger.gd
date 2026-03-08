extends Node
class_name TaxLedger

# request_id -> {requester: Node, amount: int, timestamp: int, urgency: float}
var _requests: Dictionary = {}
var _next_id: int = 0
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

func request_tax(requester: Node, amount: int, urgency: float = 50.0) -> void:
	if not is_instance_valid(requester):
		return

	var id = _next_id
	_next_id += 1
	_requests[id] = {
		"requester": requester,
		"amount": amount,
		"timestamp": Time.get_ticks_msec(),
		"urgency": urgency
	}

func get_requests() -> Array:
	_cleanup_expired()
	return _requests.values()

func has_request_from(requester: Node) -> bool:
	_cleanup_expired()
	for req in _requests.values():
		if req.requester == requester:
			return true
	return false

func get_request_amount(requester: Node) -> int:
	_cleanup_expired()
	for req in _requests.values():
		if req.requester == requester:
			return req.amount
	return 0

func clear_request(requester: Node) -> void:
	var keys_to_remove = []
	for id in _requests:
		if _requests[id].requester == requester:
			keys_to_remove.append(id)

	for id in keys_to_remove:
		_requests.erase(id)

func _cleanup_expired() -> void:
	var now = Time.get_ticks_msec()
	var keys_to_remove = []
	for id in _requests:
		if now - _requests[id].timestamp > EXPIRY_TIME_MS:
			keys_to_remove.append(id)

	for id in keys_to_remove:
		_requests.erase(id)
