extends Node3D
class_name Tracker

@onready var tracking: AgentTracking = $AgentTracking


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Establish connection to TeamMemory.
	var team = ComponentFinder.get_component(self, "TeamMemory")
	if team and not team.team_changed.is_connected(_team_changed):
		team.team_changed.connect(_team_changed)
	_team_changed(team.return_team())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _team_changed(new_team: int) -> void:
	tracking.setup_player(new_team)


func get_candidates() -> Array[Node3D]:
	return tracking.get_candidates()
