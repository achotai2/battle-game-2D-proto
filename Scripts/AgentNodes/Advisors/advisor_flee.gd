extends Advisor
class_name AdvisorFlee

@export var flee_distance: float = 10.0

func get_intent() -> Intent:
	if not agent or not agent.detection: return null

	var enemies = agent.detection.get_candidates()
	if enemies.is_empty(): return null

	var closest: Node3D = null
	var min_dist_sq: float = INF

	for e in enemies:
		if is_instance_valid(e):
			var dist_sq = agent.global_position.distance_squared_to(e.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest = e

	if closest:
		var dir = (agent.global_position - closest.global_position).normalized()
		var target = agent.global_position + dir * flee_distance
		var intent = Intent.new(20.0, self, Intent.Type.FLEE)
		intent.target_position = target
		intent.description = "Flee from enemy"
		return intent

	return null

func enact_intent(intent: Intent) -> void:
	if not agent or not agent.movement: return

	if intent.type == Intent.Type.FLEE:
		agent.movement.move_to_position(intent.target_position)
