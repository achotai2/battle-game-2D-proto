extends Area2D
class_name AgentTracking

signal target_changed(new_target: Node2D)
signal target_lost()
signal target_refreshed(current_target: Node2D)

enum TargetKind { ATTACKABLE, INTERACTABLE }

@export var my_agent: Node2D
@export var target_kind: TargetKind = TargetKind.ATTACKABLE
@export var tactical: Node = null

# Team filters (works for any number of teams; 0 = neutral)
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = false

@export var targets_self: bool = false

@export_enum("Nearest", "Strongest", "Lowest Health", "Buildings") var target_bias: String = "Nearest"
@export_range(0.05, 5.0, 0.05) var targeting_update: float = 0.5

var dont_target: Node2D = null

# Candidate set + list
var _candidates: Dictionary = {}          # Node2D -> true
var _candidate_list: Array[Node2D] = []
var _current_target: Node2D = null
var _timer: Timer

const GROUP_ATTACKABLE: StringName = "Attackable"
const GROUP_INTERACTABLE: StringName = "Interactable"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = targeting_update
	_timer.timeout.connect(_reselect_target)
	add_child(_timer)
	_timer.start(randf() * targeting_update) # stagger


# -------------------------
# Public API
# -------------------------

func set_myself(agent: Node2D) -> void:
	my_agent = agent

	dont_target = null if targets_self else agent
	if dont_target:
		_remove_candidate(dont_target)

	_reselect_target()


func get_target() -> Node2D:
	return _current_target


func get_candidates() -> Array[Node2D]:
	return _candidate_list.duplicate()


func refresh() -> void:
	# Force an immediate prune + reselection (useful when units change role/capabilities).
	_reselect_target()


func set_bias(new_bias: String) -> void:
	target_bias = new_bias
	_reselect_target()


func set_team_filters(same_team: bool, opposing: bool, neutral: bool) -> void:
	target_same_team = same_team
	target_opposing = opposing
	target_neutral = neutral
	_reselect_target()


# -------------------------
# Area callbacks
# -------------------------

func _on_body_entered(body: Node2D) -> void:
	if _is_candidate(body):
		_add_candidate(body)
		_reselect_target()

func _on_body_exited(body: Node2D) -> void:
	_remove_candidate(body)
	_reselect_target()


# -------------------------
# Candidate management
# -------------------------

func _add_candidate(body: Node2D) -> void:
	if _candidates.has(body):
		return
	_candidates[body] = true
	_candidate_list.append(body)

	# Clean up if freed/dies without body_exited
	body.tree_exited.connect(_on_candidate_tree_exited.bind(body), CONNECT_ONE_SHOT)

func _remove_candidate(body: Node2D) -> void:
	if not _candidates.has(body):
		return
	_candidates.erase(body)

	var idx := _candidate_list.find(body)
	if idx != -1:
		_candidate_list.remove_at(idx)

func _on_candidate_tree_exited(body: Node2D) -> void:
	_remove_candidate(body)
	_reselect_target()


# -------------------------
# Filtering
# -------------------------

func _team_allowed(p: int) -> bool:
	if p == my_agent.return_player():
		return target_same_team
	if p == 0:
		return target_neutral
	return target_opposing


func _is_attackable(body: Node) -> bool:
	return body.is_in_group(GROUP_ATTACKABLE)


func _is_interactable(body: Node) -> bool:
	return body.is_in_group(GROUP_INTERACTABLE)


func _is_candidate(body: Node2D) -> bool:
	if body == null or body == dont_target:
		return false

	# Capability gate
	match target_kind:
		TargetKind.ATTACKABLE:
			if not _is_attackable(body):
				return false
		TargetKind.INTERACTABLE:
			if not _is_interactable(body):
				return false

	# Team gate
	if not body.has_method("return_player"):
		return false

	return _team_allowed(body.return_player())


# -------------------------
# Target selection (O(n), no sorting)
# -------------------------

func _reselect_target() -> void:
	# Prune invalids safely (don't mutate while iterating)
	var to_remove: Array[Node2D] = []
	for b in _candidate_list:
		if not is_instance_valid(b) or not _is_candidate(b):
			to_remove.append(b)
	for b in to_remove:
		_remove_candidate(b)

	var best: Node2D = null
	for b in _candidate_list:
		if best == null:
			best = b
		elif _is_better(b, best):
			best = b

	if best != _current_target:
		_current_target = best
		if _current_target:
			target_changed.emit(_current_target)
			_notify_tactical_target_changed(_current_target)
		else:
			target_lost.emit()
			_notify_tactical_target_lost()
			
	target_refreshed.emit(_current_target)
	_notify_tactical_target_refreshed(_current_target)


func _is_better(a: Node2D, b: Node2D) -> bool:
	match target_bias:
		"Nearest":
			return _dist2(a) < _dist2(b)

		"Strongest":
			# If present, use get_strength(); else fall back to nearest
			if a.has_method("get_strength") and b.has_method("get_strength"):
				var sa = a.get_strength()
				var sb = b.get_strength()
				if sa != sb:
					return sa > sb
			return _dist2(a) < _dist2(b)

		"Lowest Health":
			var ha: float = _health_value(a)
			var hb: float = _health_value(b)
			if ha != hb:
				return ha < hb
			return _dist2(a) < _dist2(b)

		"Buildings":
			var a_build := a.is_in_group("Buildings")
			var b_build := b.is_in_group("Buildings")
			if a_build != b_build:
				return a_build and not b_build
			return _dist2(a) < _dist2(b)

		_:
			return _dist2(a) < _dist2(b)


func _dist2(n: Node2D) -> float:
	return global_position.distance_squared_to(n.global_position)


func _health_value(n: Node) -> float:
	# Only meaningful if the target has a valid health reference
	var h: Object = n.get("health")
	if not is_instance_valid(h):
		return INF

	# Support either return_health() or get_health()
	if h.has_method("return_health"):
		return float(h.call("return_health"))
	if h.has_method("get_health"):
		return float(h.call("get_health"))

	return INF


func _notify_tactical_target_changed(target: Node2D) -> void:
	if is_instance_valid(tactical) and tactical.has_method("set_target"):
		tactical.call("set_target", target)


func _notify_tactical_target_lost() -> void:
	if is_instance_valid(tactical) and tactical.has_method("clear_target"):
		tactical.call("clear_target")


func _notify_tactical_target_refreshed(target: Node2D) -> void:
	if is_instance_valid(tactical) and tactical.has_method("detection_refreshed"):
		tactical.call("detection_refreshed", target)
