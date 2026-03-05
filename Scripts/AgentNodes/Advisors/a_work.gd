extends Advisor
class_name AdvisorWork

var work_action: WorkAction = null
var movement: AgentMovement = null
var work_tasker: MinionTasker = null
var animate: AgentAnimate = null
var unit_speed: UnitSpeed = null
var arrived: bool = false

func initialize() -> void:
	if not work_action:
		work_action = ComponentFinder.get_component(self, "WorkAction")
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")
	if not work_tasker:
		work_tasker = ComponentFinder.get_component(self, "MinionTasker")
	if not unit_speed:
		unit_speed = ComponentFinder.get_component(self, "UnitSpeed")


func get_intent() -> Intent:
	if not work_tasker: return
	
	var job = work_tasker.get_current_job()

	if not job or not job.needs_work():
		job = work_tasker.get_closest_known_job()
		if job:
			work_tasker.assign_job(job)
			arrived = false

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
