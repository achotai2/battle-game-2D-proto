extends Advisor
class_name AdvisorWork

var _last_work_time: int = 0

func get_intent() -> Intent:
	if not agent or not agent.tasker: return null

	var tasker = agent.tasker
	var job = tasker.get_current_job()

	if not job:
		var intent = Intent.new(1.0, self, Intent.Type.IDLE)
		intent.description = "Looking for work"
		return intent

	if not job.needs_work():
		# Job done, release logic handled in enact or next tick
		var intent = Intent.new(1.0, self, Intent.Type.IDLE)
		return intent

	# Check distance
	var target_pos = job.get_work_position_for(agent)
	var range_sq = tasker.work_range * tasker.work_range
	var dist_sq = agent.global_position.distance_squared_to(target_pos)

	# Use a slightly larger range for state transition to avoid flickering
	if dist_sq <= range_sq:
		var intent = Intent.new(5.0, self, Intent.Type.WORK)
		intent.description = "Working"
		return intent
	else:
		var intent = Intent.new(5.0, self, Intent.Type.MOVE)
		intent.target_position = target_pos
		intent.description = "Moving to Job"
		return intent

func enact_intent(intent: Intent) -> void:
	if not agent or not agent.tasker: return

	if intent.type == Intent.Type.IDLE:
		agent.tasker.request_job()

	elif intent.type == Intent.Type.MOVE:
		if agent.movement:
			agent.movement.command_move_to_position(intent.target_position, 5)

	elif intent.type == Intent.Type.WORK:
		if agent.movement:
			agent.movement.command_start_work(5)

		var now = Time.get_ticks_msec()
		var interval_ms = int(agent.tasker.work_interval * 1000)
		if now - _last_work_time >= interval_ms:
			if agent.tasker.perform_work_tick():
				_last_work_time = now
