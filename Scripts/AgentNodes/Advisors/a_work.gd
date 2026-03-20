extends Advisor
class_name AdvisorWork

var work_action: WorkAction = null
var movement: AgentMovement = null
var work_tasker: MinionTasker = null
var animate: AgentAnimate = null
var unit_speed: UnitSpeed = null
var arrived: bool = false

func initialize() -> void:
	var base = ComponentFinder.get_base(self)
	if not work_action:
		work_action = base.get("work_action")
	if not movement:
		movement = base.get("movement")
	if not work_tasker:
		work_tasker = base.get("minion_tasker")
	if not unit_speed:
		unit_speed = base.get("unit_speed")


func get_intent() -> Intent:
	if not work_tasker: return
	
	var job = work_tasker.get_current_job()

	if not job or not job.needs_work():
		work_tasker.clear_task()
		var agent = ComponentFinder.get_base(self)
		var jobs = work_tasker.get_known_jobs_sorted_by_distance()
		for candidate in jobs:
			if candidate.assign_worker(agent):
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
	if not work_action or not movement: return

	if not intent.type == Intent.Type.WORK: return

	var job = work_tasker.get_current_job()
	if not job or not job.needs_work():
		return

	if not arrived:
		var agent = ComponentFinder.get_base(self)
		var target_pos = job.get_work_position_for(agent)
		var range_sq = work_tasker.work_range * work_tasker.work_range
		var dist_sq = agent.global_position.distance_squared_to(target_pos)

		if dist_sq <= range_sq:
			arrived = true
		else:
			# Move to work
			if unit_speed and movement:
				movement.max_speed = unit_speed.run_speed
				movement.move_to_position(target_pos)

	if arrived:
		# In range, do work
		if movement:
			movement.stop()

		if work_action:
			work_action.do_work(intent.target_node)
