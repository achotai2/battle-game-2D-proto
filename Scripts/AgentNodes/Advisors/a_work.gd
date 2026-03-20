extends Advisor
class_name AdvisorWork

var _agent: AgentBase = null

var work_action: WorkAction = null
var movement: AgentMovement = null
var work_tasker: MinionTasker = null
var animate: AgentAnimate = null
var unit_speed: UnitSpeed = null
var arrived: bool = false

func initialize() -> void:
	# 1. Safely grab the root agent once
	_agent = _find_root_base(self) as AgentBase
	
	if is_instance_valid(_agent):
		# 2. Directly grab all components from the agent
		work_action = _agent.get("work_action")
		movement = _agent.get("movement")
		work_tasker = _agent.get("minion_tasker")
		unit_speed = _agent.get("unit_speed")
		animate = _agent.get("animate")

		if is_instance_valid(work_tasker):
			if not work_tasker.task_changed.is_connected(_on_task_changed):
				work_tasker.task_changed.connect(_on_task_changed)

		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(request_intent_update)
		add_child(timer)

func _on_task_changed() -> void:
	request_intent_update()

func _calculate_intent() -> Intent:
	if not work_tasker or not is_instance_valid(_agent): return null
	
	var job = work_tasker.get_current_job()

	if not job or not job.needs_work():
		work_tasker.clear_task()
		var jobs = work_tasker.get_known_jobs_sorted_by_distance()
		for candidate in jobs:
			if candidate.assign_worker(_agent):
				job = candidate
				work_tasker.assign_job(job)
				arrived = false
				break

	if not job:
		var intent = Intent.new(0.0, self, Intent.Type.IDLE)
		intent.description = "Looking for work"
		return intent

	var intent = Intent.new(50.0, self, Intent.Type.WORK)
	intent.target_node = job
	intent.description = "Working or moving to job"
	return intent


func enact_intent(intent: Intent) -> void:
	if not work_action or not movement or not is_instance_valid(_agent): return

	if not intent.type == Intent.Type.WORK: return

	var job = work_tasker.get_current_job()
	if not job or not job.needs_work():
		return

	if not arrived:
		var target_pos = job.get_work_position_for(_agent)
		var range_sq = work_tasker.work_range * work_tasker.work_range
		var dist_sq = _agent.global_position.distance_squared_to(target_pos)

		if dist_sq <= range_sq:
			arrived = true
		else:
			# Move to work (AgentMovement will handle the play_walk() visuals automatically!)
			if unit_speed and movement:
				movement.max_speed = unit_speed.run_speed
				movement.move_to_position(target_pos)

	if arrived:
		# In range, stop walking
		if movement:
			movement.stop()

		# EXPLICIT ANIMATION COMMAND: Face the tree/building
		if is_instance_valid(animate) and animate.has_method("face_target"):
			animate.face_target(job.global_position)

		# Execute the mechanical work logic
		if work_action:
			work_action.do_work(intent.target_node)
			
		# EXPLICIT ANIMATION COMMAND: Swing the tool!
		if is_instance_valid(animate) and animate.has_method("play_work"):
			animate.play_work()


# --- HELPERS ---

func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != start_node.get_tree().root:
		if current is AgentBase:
			return current as Node3D
		current = current.get_parent()
	return null
