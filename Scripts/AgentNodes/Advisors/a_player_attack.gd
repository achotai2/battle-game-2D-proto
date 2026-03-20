extends Advisor
class_name AdvisorPlayerAttack

var _agent: AgentBase = null
var _vision_tracker: Tracker = null
var _weapon: Node = null

var _current_target: Node3D = null

func initialize() -> void:
	if not _agent:
		_agent = ComponentFinder.get_base(self)
		
	if _agent:
		# 1. Grab the main vision sensor (No need for UnitSpeed since we don't move!)
		if not _vision_tracker:
			_vision_tracker = ComponentFinder.get_component(self, "Tracker")
		
		# 2. Grab the equipped weapon
		var _weapon_folder: Node3D = ComponentFinder.get_component(self, "Node3D", "Weapons")
		if is_instance_valid(_weapon_folder):
			for child in _weapon_folder.get_children():
				if child.has_method("perform_attack_tick"):
					_weapon = child
					break


func get_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_weapon):
		return null
		
	if not _vision_tracker:
		return null

	var enemies = _vision_tracker.get_candidates()
	if enemies.is_empty():
		_current_target = null
		return null

	var best_target: Node3D = null

	# Sticky Targeting: Keep focusing the same enemy if they are still around
	if is_instance_valid(_current_target) and enemies.has(_current_target):
		best_target = _current_target
	else:
		var min_dist_sq: float = INF
		var agent_pos = _agent.global_position

		for e in enemies:
			if not is_instance_valid(e):
				continue
				
			var dist_sq = agent_pos.distance_squared_to(e.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_target = e
				
		_current_target = best_target

	if not best_target:
		return null

	# ONLY return an intent if the target is already in physical strike range
	if _weapon.is_target_in_range(best_target):
		var intent = Intent.new(50.0, self, Intent.Type.ATTACK) 
		intent.target_node = best_target
		intent.description = "Auto-Attacking " + best_target.name
		return intent
	
	# If they are out of range, do absolutely nothing. The player must walk closer manually.
	return null


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.ATTACK:
		if _agent.movement:
			_agent.movement.stop()

		# Let the animation component handle the visual flipping!
		if _agent.animate and _agent.animate.has_method("face_target"):
			_agent.animate.face_target(target.global_position)

		# Trigger the weapon logic
		if is_instance_valid(_weapon):
			var attack_started = _weapon.perform_attack_tick(target)
			
			if attack_started and _agent.animate and _agent.animate.has_method("play_attack"):
				_agent.animate.play_attack(target)
