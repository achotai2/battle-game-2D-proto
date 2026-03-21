extends Node3D
class_name Tracker

# 1. Declare the missing signals so Advisors can connect to them!
signal target_changed(target: Node3D)
signal target_lost()

@onready var tracking: AgentTracking = $AgentTracking
var _my_team = null

func _ready() -> void:
	# 2. Wire up the Signal Forwarding
	if is_instance_valid(tracking):
		if tracking.has_signal("target_changed"):
			tracking.target_changed.connect(_on_tracking_target_changed)
		if tracking.has_signal("target_lost"):
			tracking.target_lost.connect(_on_tracking_target_lost)

	# 3. Safely grab the team without the ComponentFinder
	var base = _find_root_base(self)
	if is_instance_valid(base):
		_my_team = base.get("team")
		if not _my_team:
			_my_team = base.get("team_memory")

		if is_instance_valid(_my_team):
			if not _my_team.team_changed.is_connected(_team_changed):
				_my_team.team_changed.connect(_team_changed)
			
			if _my_team.has_method("return_team"):
				_team_changed(_my_team.return_team())


func _team_changed(new_team: int) -> void:
	if is_instance_valid(tracking) and tracking.has_method("setup_player"):
		tracking.setup_player(new_team)


func get_candidates() -> Array[Node3D]:
	if is_instance_valid(tracking) and tracking.has_method("get_candidates"):
		return tracking.get_candidates()
	return []


# --- SIGNAL FORWARDERS ---

func _on_tracking_target_changed(target: Node3D) -> void:
	target_changed.emit(target)

func _on_tracking_target_lost() -> void:
	target_lost.emit()


# --- HELPERS ---

func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase or current.has_method("return_castle"):
			return current as Node3D
		current = current.get_parent()
	return null
