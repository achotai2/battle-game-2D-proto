extends Advisor
class_name AdvisorAttack

func get_intent() -> Intent:
	if not agent or not agent.detection: return null

	# 1. Find a target via main detection (Vision)
	# AgentTracking.get_candidates() returns list. We pick closest or current.
	# We need to maintain a current target to avoid switching too often?
	# Or just pick closest.

	var enemies = agent.detection.get_candidates()
	if enemies.is_empty(): return null

	var best_target: AgentBase = null
	var min_dist_sq: float = INF

	for e in enemies:
		if is_instance_valid(e):
			var dist_sq = agent.global_position.distance_squared_to(e.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_target = e

	if not best_target: return null

	# 2. Check if we can attack it
	var weapon = agent.attack
	if not weapon:
		# No weapon, just chase? Or flee?
		# If we are an AdvisorAttack, we assume we want to attack.
		var intent = Intent.new(10.0, self, Intent.Type.CHASE)
		intent.target_node = best_target
		intent.description = "Chasing (No Weapon)"
		return intent

	# Check range via Weapon
	if weapon.has_method("is_target_in_range") and weapon.is_target_in_range(best_target):
		var intent = Intent.new(10.0, self, Intent.Type.ATTACK)
		intent.target_node = best_target
		intent.description = "Attacking"
		return intent
	else:
		var intent = Intent.new(10.0, self, Intent.Type.CHASE)
		intent.target_node = best_target
		intent.description = "Chasing"
		return intent

func enact_intent(intent: Intent) -> void:
	if not agent or not agent.movement: return

	if intent.type == Intent.Type.CHASE:
		if is_instance_valid(intent.target_node):
			agent.movement.move_to_position(intent.target_node.global_position)
	elif intent.type == Intent.Type.ATTACK:
		agent.movement.stop()

		if is_instance_valid(intent.target_node):
			var dir = agent.global_position.direction_to(intent.target_node.global_position)
			dir.y = 0
			if not dir.is_zero_approx():
				agent.look_at(agent.global_position + dir, Vector3.UP)

			if agent.animation:
				agent.animation.play_attack(intent.target_node)

		# Perform attack tick on weapon (usually deals damage)
		if agent.attack and agent.attack.has_method("perform_attack_tick"):
			agent.attack.perform_attack_tick(intent.target_node)
