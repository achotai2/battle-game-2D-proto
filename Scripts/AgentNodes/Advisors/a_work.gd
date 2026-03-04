extends Advisor
class_name AdvisorWork

var work_action: Node = null

func initialize() -> void:
	if not agent:
		agent = ComponentFinder.get_base(self)
	if not work_action:
		work_action = ComponentFinder.get_component(self, "WorkAction")

func get_intent() -> Intent:
	if not agent or not agent.tasker: return null

	var tasker = agent.tasker
	var job = tasker.get_current_job()

	if not is_instance_valid(job) or not job.needs_work():
		job = tasker.get_closest_known_job()
		if job:
			tasker.assign_job(job)

	if not job:
		var intent = Intent.new(1.0, self, Intent.Type.IDLE)
		intent.description = "Looking for work"
		return intent

	var intent = Intent.new(50.0, self, Intent.Type.WORK)
	intent.target_node = job
	intent.description = "Working or moving to job"
	return intent

func enact_intent(intent: Intent) -> void:
	if not agent or not agent.tasker: return

	if intent.type == Intent.Type.IDLE:
		if agent.tasker.has_method("request_job"):
			agent.tasker.request_job()

	elif intent.type == Intent.Type.WORK:
		if work_action and work_action.has_method("do_work"):
			work_action.do_work(intent.target_node)
