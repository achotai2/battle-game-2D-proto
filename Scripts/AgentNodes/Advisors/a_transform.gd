extends Advisor
class_name AdvisorTransform

var movement: AgentMovement = null
var work_tasker: MinionTasker = null
var unit_speed: UnitSpeed = null
var agent: AgentBase = null
var arrived: bool = false

func initialize() -> void:
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")
	if not work_tasker:
		work_tasker = ComponentFinder.get_component(self, "MinionTasker")
	if not unit_speed:
		unit_speed = ComponentFinder.get_component(self, "UnitSpeed")
	if not agent:
		agent = ComponentFinder.get_base(self)


func get_intent() -> Intent:
	if not work_tasker: return null

	var job = work_tasker.get_current_job()

	if not job or not job.needs_work():
		work_tasker.clear_task()
		var agent = ComponentFinder.get_base(self)
		var jobs = work_tasker.get_known_jobs_sorted_by_distance()
		for candidate in jobs:
			if candidate is SpawnSite and candidate.assign_worker(agent):
				job = candidate
				work_tasker.assign_job(job)
				arrived = false
				break

	if not job:
		var intent = Intent.new(0.0, self, Intent.Type.IDLE)
		intent.description = "Looking for a spawnsite"
		return intent

	var intent = Intent.new(50.0, self, Intent.Type.WORK)
	intent.target_node = job
	intent.description = "Moving to spawnsite"
	return intent

func enact_intent(intent: Intent) -> void:
	if not movement: return

	if not intent.type == Intent.Type.WORK: return

	var job = work_tasker.get_current_job()
	if not job or not job.needs_work() or not job is SpawnSite:
		return

	if not arrived:
		var target_pos = job.get_work_position_for(agent)
		var range_sq = work_tasker.work_range * work_tasker.work_range
		var dist_sq = agent.global_position.distance_squared_to(target_pos)

		if dist_sq <= range_sq:
			arrived = true
		else:
			# Move to spawnsite
			if unit_speed and movement:
				movement.max_speed = unit_speed.run_speed
				movement.move_to_position(target_pos)

	if arrived:
		if movement:
			movement.stop()
		# The SpawnSite's apply_work function will catch this and emit the transform signal!
		if job.has_method("apply_work"):
			job.apply_work(1.0, agent)
