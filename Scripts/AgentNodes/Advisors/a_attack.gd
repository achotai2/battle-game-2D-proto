extends Advisor
class_name AdvisorAttack

var _agent: AgentBase = null
var _vision_tracker: Tracker = null
var _weapon: Node = null
var _unitSpeed: UnitSpeed = null


func initialize() -> void:
	if not _agent:
		_agent = ComponentFinder.get_base(self)
		
	if _agent:
		# 1. Grab the main vision sensor and speed
		if not _vision_tracker:
			_vision_tracker = _agent.tracker

		if not _unitSpeed:
			_unitSpeed = _agent.unit_speed
		
		# 2. Grab the equipped weapon
		var _weapon_folder: Node3D = _agent.get("weapons_node")
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

	# 1. Find enemies within the main Vision radius
	var enemies = _vision_tracker.get_candidates()
	if enemies.is_empty():
		return null

	var best_target: Node3D = null
	var min_dist_sq: float = INF
	var agent_pos = _agent.global_position

	# Find the closest valid enemy
	for e in enemies:
		if not is_instance_valid(e):
			continue
			
		var dist_sq = agent_pos.distance_squared_to(e.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_target = e

	if not best_target:
		return null

	# 2. Ask the weapon if the target has entered the physical strike range
	if _weapon.is_target_in_range(best_target):
		# High priority: Swing the sword!
		var intent = Intent.new(80.0, self, Intent.Type.ATTACK) 
		intent.target_node = best_target
		intent.description = "Attacking " + best_target.name
		return intent
	else:
		# Medium priority: Run towards them!
		var intent = Intent.new(70.0, self, Intent.Type.CHASE) 
		intent.target_node = best_target
		intent.description = "Chasing " + best_target.name
		return intent

func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.CHASE:
		if _agent.movement:
			if _unitSpeed:
				_agent.movement.max_speed = _unitSpeed.run_speed
			_agent.movement.move_to_position(target.global_position)
			
	elif intent.type == Intent.Type.ATTACK:
		if _agent.movement:
			_agent.movement.stop()

		# Face the target, keeping the Y-axis locked so the unit doesn't tilt upward
		var look_pos = Vector3(target.global_position.x, _agent.global_position.y, target.global_position.z)
		if not _agent.global_position.is_equal_approx(look_pos):
			_agent.look_at(look_pos, Vector3.UP)

		# Trigger the weapon logic
		if is_instance_valid(_weapon):
			var attack_started = _weapon.perform_attack_tick(target)
			
			# Only play the animation if the weapon isn't on cooldown!
			if attack_started and _agent.animate and _agent.animate.has_method("play_attack"):
				_agent.animate.play_attack(target)
