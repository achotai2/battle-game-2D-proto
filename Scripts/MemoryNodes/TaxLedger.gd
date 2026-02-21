extends Node
class_name TaxLedger

# request_id -> {requester: Node, amount: int, timestamp: int}
var _requests: Dictionary = {}
var _next_id: int = 0
const EXPIRY_TIME_MS: int = 60000 # 1 minute

func request_tax(requester: Node, amount: int) -> void:
	if not is_instance_valid(requester):
		return

	var id = _next_id
	_next_id += 1
	_requests[id] = {
		"requester": requester,
		"amount": amount,
		"timestamp": Time.get_ticks_msec()
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
