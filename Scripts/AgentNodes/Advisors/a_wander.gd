extends Advisor
class_name AdvisorWander

@export var wander_radius: float = 10.0
@export var min_wander_distance: float = 2.0

var _current_target: Vector3 = Vector3.ZERO
var _has_target: bool = false

func get_intent() -> Intent:
#	if not is_instance_valid(agent): return null

	# Check if we have arrived at current target
	if _has_target:
#		var dist_sq = agent.global_position.distance_squared_to(_current_target)
#		if dist_sq < 2.0: # Arrival threshold
			_has_target = false

	if not _has_target:
		_pick_new_target()

	if _has_target:
		var intent = Intent.new(1.0, self, Intent.Type.MOVE)
		intent.target_position = _current_target
		intent.description = "Wander around castle"
		return intent

	return null

func _pick_new_target() -> void:
#	if not is_instance_valid(agent): return

#	var center = agent.global_position
#	if is_instance_valid(agent.castle):
#		center = agent.castle.global_position

	var angle = randf() * TAU
	var r = sqrt(randf()) * wander_radius
	# Ensure min distance from center if needed, but simple circle is fine

#	_current_target = center + Vector3(cos(angle), 0, sin(angle)) * r
	_has_target = true

func enact_intent(intent: Intent) -> void:
	pass
#	if not agent or not agent.movement: return

#	if intent.type == Intent.Type.MOVE:
#		agent.movement.move_to_position(intent.target_position)
