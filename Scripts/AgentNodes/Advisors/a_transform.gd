extends Advisor
class_name AdvisorTransform

var movement: AgentMovement = null
var work_tasker: Node = null
var unit_speed: Node = null
var animate: Node = null

var arrived: bool = false
var _job_search_timer: Timer = null


func initialize() -> void:
	# 1. Safely grab the root agent
	if not is_instance_valid(_agent):
		_agent = _find_root_base(self)
		
	if is_instance_valid(_agent):
		# 2. Grab components directly from AgentBase
		movement = _agent.get("movement")
		work_tasker = _agent.get("minion_tasker")
		unit_speed = _agent.get("unit_speed")
		animate = _agent.get("animate")

		# 3. Connect to Discrete Task Signals
		if is_instance_valid(work_tasker):
			if work_tasker.has_signal("task_changed") and not work_tasker.task_changed.is_connected(_on_task_changed):
				work_tasker.task_changed.connect(_on_task_changed)

		# 4. Setup Smart Job Search Timer
		if not is_instance_valid(_job_search_timer):
			_job_search_timer = Timer.new()
			_job_search_timer.wait_time = 0.5
			_job_search_timer.autostart = true # Starts awake to look for jobs!
			_job_search_timer.timeout.connect(request_intent_update)
			add_child(_job_search_timer)


# --- EVENT TRIGGERS ---

func _on_task_changed() -> void:
	arrived = false
	request_intent_update()


# --- INTENT LOGIC ---

func _calculate_intent() -> Intent:
	if not is_instance_valid(work_tasker) or not is_instance_valid(_agent):
		return null

	var job = null
	if work_tasker.has_method("get_current_job"):
		job = work_tasker.get_current_job()

	# If we have no job, or the job is broken, search for a SpawnSite!
	if not is_instance_valid(job) or (job.has_method("needs_work") and not job.needs_work()):
		if work_tasker.has_method("clear_task"):
			work_tasker.clear_task()
			
		if work_tasker.has_method("get_known_jobs_sorted_by_distance"):
			var jobs = work_tasker.get_known_jobs_sorted_by_distance()
			for candidate in jobs:
				# ONLY accept SpawnSites for this specific Advisor
				if candidate.get_class() == "SpawnSite" or candidate.has_method("apply_work"): 
					if candidate.has_method("assign_worker") and candidate.assign_worker(_agent):
						job = candidate
						if work_tasker.has_method("assign_job"):
							work_tasker.assign_job(job)
						arrived = false
						break

	# If we STILL have no job, put the intent to sleep and keep the timer running
	if not is_instance_valid(job):
		if is_instance_valid(_job_search_timer) and _job_search_timer.is_stopped():
			_job_search_timer.start()
		return null

	# We found a job! Put the timer to sleep to save CPU.
	if is_instance_valid(_job_search_timer):
		_job_search_timer.stop()

	# Priority 60.0 cleanly overrides standard Work (50.0)
	var intent = Intent.new(60.0, self, Intent.Type.WORK)
	intent.target_node = job
	intent.description = "Moving to SpawnSite"
	return intent


func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(movement) or not is_instance_valid(_agent): return
	if intent.type != Intent.Type.WORK: return

	var job = intent.target_node
	if not is_instance_valid(job):
		return

	if not arrived:
		var target_pos = job.global_position
		if job.has_method("get_work_position_for"):
			target_pos = job.get_work_position_for(_agent)
			
		var range_sq = 4.0 # Default fallback range
		if is_instance_valid(work_tasker) and "work_range" in work_tasker:
			range_sq = work_tasker.work_range * work_tasker.work_range
			
		var dist_sq = _agent.global_position.distance_squared_to(target_pos)

		if dist_sq <= range_sq:
			arrived = true
		else:
			# Sprint to the spawnsite
			if is_instance_valid(unit_speed) and "run_speed" in unit_speed:
				movement.max_speed = unit_speed.run_speed
			movement.move_to_position(target_pos)

	if arrived:
		# Halt movement
		movement.stop()
		
		# Explicit Animation: Face the building while transforming!
		if is_instance_valid(animate):
			if animate.has_method("face_target"):
				animate.face_target(job.global_position)
			if animate.has_method("play_idle"):
				animate.play_idle()
		
		# Trigger the transformation
		print("BREADCRUMB 1: Attempting to apply work...")
		if job.has_method("apply_work"):
			job.apply_work(1.0, _agent)
		print("BREADCRUMB 2: Work applied successfully!")


# --- HELPERS ---

func _find_root_base(start_node: Node) -> AgentBase:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase:
			return current as AgentBase
		current = current.get_parent()
	return null
