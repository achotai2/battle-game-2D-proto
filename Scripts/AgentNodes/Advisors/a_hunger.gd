extends Advisor
class_name AdvisorHunger

# --- CONFIGURATION ---
@export var min_hunger: int = 0
@export var hunger_start_threshold: int = 50
@export var max_priority: float = 100.0

# --- COMPONENTS ---
var _agent: AgentBase = null
var hunger: Node = null
var tasker: Node = null
var movement: AgentMovement = null
var unit_speed: Node = null
var animate: Node = null
var work_action: Node = null 

var arrived: bool = false


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)

	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		hunger = _agent.get("hunger_holder")
		tasker = _agent.get("minion_tasker")
		movement = _agent.get("movement")
		unit_speed = _agent.get("unit_speed")
		animate = _agent.get("animate")
		work_action = _agent.get("work_action")

		# 3. Connect Event-Driven Signals (No timers needed!)
		if is_instance_valid(hunger):
			if hunger.has_signal("food_changed") and not hunger.food_changed.is_connected(_on_food_changed):
				hunger.food_changed.connect(_on_food_changed)

		if is_instance_valid(tasker):
			# Note: Ensure MinionTasker actually emits this signal!
			if tasker.has_signal("task_changed") and not tasker.task_changed.is_connected(_on_task_changed):
				tasker.task_changed.connect(_on_task_changed)


# --- EVENT TRIGGERS ---

func _on_food_changed(_food: int) -> void:
	request_intent_update()


func _on_task_changed() -> void:
	# If our food job gets destroyed or completed, reset our arrival flag!
	arrived = false 
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(hunger) or not is_instance_valid(tasker):
		return null

	var current_food = hunger.get_food()

	# If we are full enough, don't emit an intent at all
	if current_food > hunger_start_threshold:
		return null

	# The hungrier we are, the higher the priority scales (from 8.0 up to 100.0)
	var t = clamp(inverse_lerp(hunger_start_threshold, min_hunger, current_food), 0.0, 1.0)
	var priority = lerp(8.0, max_priority, t)

	# Check if tasker has a food job
	if not tasker.has_task():
		if tasker.has_method("request_job"):
			tasker.request_job() # (Assuming you pass a parameter here if jobs are filtered by type!)

		# If still no food available, we just have to starve and keep working/idling
		if not tasker.has_task():
			return null

	# We found a place to eat!
	var job_site = tasker.get_current_job()
	if not is_instance_valid(job_site) or not "global_position" in job_site:
		return null

	var intent = Intent.new(priority, self, Intent.Type.WORK)
	intent.description = "Finding Food"
	intent.target_node = job_site
	
	# Pass both the node (for interaction) and the vector (for movement)
	intent.target_vector = job_site.global_position

	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(tasker) or not is_instance_valid(movement):
		return

	var job_site = intent.target_node
	if not is_instance_valid(job_site):
		return

	if not arrived:
		# Ask the job site where we should stand to eat
		var target_pos = job_site.global_position
		if job_site.has_method("get_work_position_for"):
			target_pos = job_site.get_work_position_for(_agent)
			
		var range_sq = tasker.work_range * tasker.work_range
		var dist_sq = _agent.global_position.distance_squared_to(target_pos)

		if dist_sq <= range_sq:
			arrived = true
		else:
			# Sprint to the food!
			if is_instance_valid(unit_speed):
				movement.max_speed = unit_speed.run_speed
			movement.move_to_position(target_pos)

	if arrived:
		# Stop moving
		movement.stop()

		# Explicit Visuals: Face the food and play the animation
		if is_instance_valid(animate):
			if animate.has_method("face_target"):
				animate.face_target(job_site.global_position)
			if animate.has_method("play_work"): # Or play_eat() if you add one!
				animate.play_work()

		# Execute the mechanical consumption logic
		if is_instance_valid(work_action) and work_action.has_method("do_work"):
			work_action.do_work(job_site)
		elif tasker.has_method("perform_work_tick"):
			tasker.perform_work_tick()


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
