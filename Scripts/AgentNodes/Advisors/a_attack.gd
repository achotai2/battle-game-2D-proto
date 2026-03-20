extends Advisor
class_name AdvisorAttack

var _agent: AgentBase = null
var _vision_tracker: Tracker = null
var _weapon: Node = null
var _unitSpeed: UnitSpeed = null
var _current_target: Node3D = null


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

		if _vision_tracker:
			if not _vision_tracker.target_changed.is_connected(_on_target_changed):
				_vision_tracker.target_changed.connect(_on_target_changed)
			if not _vision_tracker.target_lost.is_connected(_on_target_lost):
				_vision_tracker.target_lost.connect(_on_target_lost)

		var timer = Timer.new()
		timer.wait_time = 0.25
		timer.autostart = true
		timer.timeout.connect(request_intent_update)
		add_child(timer)

func _on_target_changed(target: Node3D) -> void:
	request_intent_update()

func _on_target_lost() -> void:
	request_intent_update()

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_weapon):
		return null
		
	if not _vision_tracker:
		return null

	var enemies = _vision_tracker.get_candidates()
	if enemies.is_empty():
		_current_target = null
		return null

	var best_target: Node3D = null

	# STICKY TARGETING: If we already have a target, and they are still in our vision ring, keep hitting them!
	if is_instance_valid(_current_target) and enemies.has(_current_target):
		best_target = _current_target
	else:
		# Otherwise, find the new closest enemy
		var min_dist_sq: float = INF
		var agent_pos = _agent.global_position

		for e in enemies:
			if not is_instance_valid(e):
				continue
				
			var dist_sq = agent_pos.distance_squared_to(e.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_target = e
				
		# Memorize the new target
		_current_target = best_target

	# If we somehow still failed to find a target, bail out
	if not best_target:
		return null

	# 2. Ask the weapon if the target has entered the physical strike range
	if _weapon.is_target_in_range(best_target):
		var intent = Intent.new(80.0, self, Intent.Type.ATTACK) 
		intent.target_node = best_target
		intent.description = "Attacking " + best_target.name
		return intent
	else:
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

		# Let the animation component handle the visual flipping!
		if _agent.animate and _agent.animate.has_method("face_target"):
			_agent.animate.face_target(target.global_position)

		# Trigger the weapon logic
		if is_instance_valid(_weapon):
			var attack_started = _weapon.perform_attack_tick(target)
			
			# Only play the animation if the weapon isn't on cooldown!
			if attack_started and _agent.animate and _agent.animate.has_method("play_attack"):
				_agent.animate.play_attack(target)
