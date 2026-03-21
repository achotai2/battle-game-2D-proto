extends Advisor
class_name AdvisorPlayerAttack

var _agent: AgentBase = null
var _vision_tracker: Tracker = null
var _weapon: Node = null
var _current_target: Node3D = null

var _distance_timer: Timer = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)
		
	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		_vision_tracker = _agent.tracker
		
		var _weapon_folder: Node3D = _agent.weapons_node
		if is_instance_valid(_weapon_folder):
			for child in _weapon_folder.get_children():
				if child.has_method("perform_attack_tick"):
					_weapon = child
					break

		# 3. Connect Discrete Signals
		if is_instance_valid(_vision_tracker):
			if not _vision_tracker.target_changed.is_connected(_on_target_changed):
				_vision_tracker.target_changed.connect(_on_target_changed)
			if not _vision_tracker.target_lost.is_connected(_on_target_lost):
				_vision_tracker.target_lost.connect(_on_target_lost)

		# 4. Setup Continuous Timer (Asleep by default!)
		if not is_instance_valid(_distance_timer):
			_distance_timer = Timer.new()
			_distance_timer.wait_time = 0.25
			_distance_timer.autostart = false 
			_distance_timer.timeout.connect(request_intent_update)
			add_child(_distance_timer)


# --- EVENT TRIGGERS ---

func _on_target_changed(_target: Node3D) -> void:
	# Wake up the distance tracker because an enemy arrived!
	if is_instance_valid(_distance_timer) and _distance_timer.is_stopped():
		_distance_timer.start()
		
	request_intent_update()


func _on_target_lost() -> void:
	# If all enemies are dead or gone, put the timer back to sleep!
	if is_instance_valid(_vision_tracker) and _vision_tracker.get_candidates().is_empty():
		if is_instance_valid(_distance_timer):
			_distance_timer.stop()
			
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(_agent) or not is_instance_valid(_weapon):
		return null
		
	if not is_instance_valid(_vision_tracker):
		return null

	var enemies = _vision_tracker.get_candidates()
	if enemies.is_empty():
		_current_target = null
		return null

	var best_target: Node3D = null

	# STICKY TARGETING: Keep focusing the same enemy if they are still around
	if is_instance_valid(_current_target) and enemies.has(_current_target):
		best_target = _current_target
	else:
		var min_dist_sq: float = INF
		var agent_pos = _agent.global_position

		for e in enemies:
			if not is_instance_valid(e): continue
				
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
	
	# If they are out of range, do absolutely nothing.
	return null


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(intent.target_node):
		return

	var target = intent.target_node

	if intent.type == Intent.Type.ATTACK:
		# Stop any residual sliding from manual player input
		var movement = _agent.get("movement")
		if is_instance_valid(movement) and movement.has_method("stop"):
			movement.stop()

		# Explicit Visuals: Face target
		var animate = _agent.get("animate")
		if is_instance_valid(animate) and animate.has_method("face_target"):
			animate.face_target(target.global_position)

		# Trigger the weapon logic
		if is_instance_valid(_weapon):
			var attack_started = _weapon.perform_attack_tick(target)
			
			if attack_started and is_instance_valid(animate) and animate.has_method("play_attack"):
				animate.play_attack(target)


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
