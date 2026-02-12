extends Area2D
class_name AgentTracking

signal target_changed(new_target: Node2D)
signal target_lost()
signal target_refreshed(current_target: Node2D)

enum TargetKind { ATTACKABLE, INTERACTABLE }

@export var my_agent: Node2D
@export var target_kind: TargetKind = TargetKind.ATTACKABLE:
	set(v):
		target_kind = v
		_refresh_candidates()

@export var tactical: Node = null

# Team filters (works for any number of teams; 0 = neutral)
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = false

@export var targets_self: bool = false

@export_enum("Nearest", "Strongest", "Lowest Health", "Buildings") var target_bias: String = "Nearest"
@export_range(0.05, 5.0, 0.05) var targeting_update: float = 0.5

var dont_target: Node2D = null

var _current_target: Node2D = null
var _candidates: Array[Node2D] = []
var _timer: Timer

# Bolt Optimization: Cache player ID to avoid repeated function calls
var _my_player_id: int = -1
var _has_player_method: bool = false

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

	# Bolt Optimization: Update cached player info
	if is_instance_valid(my_agent) and my_agent.has_method("return_player"):
		_my_player_id = my_agent.return_player()
		_has_player_method = true
	else:
		_my_player_id = -1
		_has_player_method = false

	dont_target = null if targets_self else agent

	_reselect_target()


func set_tactical(t: Node) -> void:
	tactical = t


func get_target() -> Node2D:
	return _current_target


func get_candidates() -> Array[Node2D]:
	var valid_candidates: Array[Node2D] = []
	for body in _candidates:
		if _is_valid_target(body):
			valid_candidates.append(body)
	return valid_candidates


func _refresh_candidates() -> void:
	_candidates.clear()
	for body in get_overlapping_bodies():
		if _is_candidate_type(body):
			_candidates.append(body)
	_reselect_target()


func refresh() -> void:
	# Force an immediate reselection
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
	if _is_candidate_type(body):
		if not body in _candidates:
			_candidates.append(body)

		if _is_valid_target(body):
			_reselect_target()

func _on_body_exited(body: Node2D) -> void:
	if body in _candidates:
		_candidates.erase(body)

	if body == _current_target:
		_reselect_target()


# -------------------------
# Filtering
# -------------------------

func _team_allowed(p: int) -> bool:
	# Bolt Optimization: Use cached values
	if not is_instance_valid(my_agent) or not _has_player_method:
		return false
	if p == _my_player_id:
		return target_same_team
	if p == 0:
		return target_neutral
	return target_opposing


func _is_attackable(body: Node) -> bool:
	return body.is_in_group(GROUP_ATTACKABLE)


func _is_interactable(body: Node) -> bool:
	return body.is_in_group(GROUP_INTERACTABLE)


func _is_candidate_type(body: Node2D) -> bool:
	if not is_instance_valid(body):
		return false

	# Capability gate (Static Check)
	match target_kind:
		TargetKind.ATTACKABLE:
			if not _is_attackable(body):
				return false
		TargetKind.INTERACTABLE:
			if not _is_interactable(body):
				return false

	# Team gate (Static Check)
	return body.has_method("return_player")


func _is_valid_target(body: Node2D) -> bool:
	if body == null or body == dont_target:
		return false

	if not is_instance_valid(body):
		return false

	# Ensure the body still matches the targeting criteria (e.g. group membership)
	if not _is_candidate_type(body):
		return false

	# Team gate (Dynamic Check)
	return _team_allowed(body.return_player())


# -------------------------
# Target selection
# -------------------------

func _reselect_target() -> void:
	# Optimization: Iterate cached candidates instead of all overlapping bodies
	var best: Node2D = null

	# Bolt Optimization: Fast path for Nearest to avoid repeated function calls and property access
	if target_bias == "Nearest":
		var my_pos := global_position
		var best_dist_sq := INF

		for b in _candidates:
			if not _is_valid_target(b):
				continue

			var d := my_pos.distance_squared_to(b.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				best = b
	elif target_bias == "Lowest Health":
		var my_pos := global_position
		var best_health := INF
		var best_dist_sq := INF

		for b in _candidates:
			if not _is_valid_target(b):
				continue

			var h := _health_value(b)

			if h < best_health:
				best_health = h
				best_dist_sq = my_pos.distance_squared_to(b.global_position)
				best = b
			elif h == best_health:
				var d := my_pos.distance_squared_to(b.global_position)
				if d < best_dist_sq:
					best_dist_sq = d
					best = b
	else:
		for b in _candidates:
			if not _is_valid_target(b):
				continue

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
	var h = n.get("health")

	if h is Health:
		return float(h.return_health())

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
