extends Advisor
class_name HungerAdvisor

var hunger: FoodStorage = null
var tasker: MinionTasker = null

# Configuration (mirrored from HungerHolder default, but should be configurable)
var min_hunger: int = 0
var hunger_start_threshold: int = 50
var max_priority: float = 100.0


func initialize() -> void:
	if not hunger:
		ComponentFinder.get_component(self, "HungerHolder")


func get_intent() -> Intent:
	if not is_instance_valid(hunger) or not is_instance_valid(tasker):
		return null

	var current_food = hunger.get_food()

	if current_food > hunger_start_threshold:
		return null

	# Calculate priority based on hunger
	# Linear interpolation: low priority at threshold, max at min_hunger
	var t = clamp(inverse_lerp(hunger_start_threshold, min_hunger, current_food), 0.0, 1.0)
	var priority = lerp(8.0, max_priority, t)

	# Check if tasker has a job
	if not tasker.has_task():
		tasker.request_job()

		# If still no task, we can't do anything yet.
		if not tasker.has_task():
			return null

	# If tasker has a job, we return an Intent to execute it with high priority
	var job_site = tasker.get_current_job()
	if not is_instance_valid(job_site) or not "global_position" in job_site:
		return null

	var intent = Intent.new(priority, self, Intent.Type.WORK)
	intent.description = "Finding Food"
	intent.target_object = job_site
	# Intent usually needs target position
	intent.target_position = job_site.global_position

	return intent

func enact_intent(intent: Intent) -> void:
	if not is_instance_valid(tasker):
		return

	# Move to target
	# Advisor usually handles movement?
	# AgentBase uses 'Advisor' to control movement.
	# But MinionTasker.perform_work_tick handles interaction.
	# We need to move to the job site.

#	if is_instance_valid(agent.movement) and is_instance_valid(intent.target_object):
		# Delegate movement to AgentMovement
		# But wait, MinionTasker usually needs to be close.
		# AdvisorWork logic:
		# if not in range: move_to
		# else: perform_work_tick

		# We can reuse similar logic
#		var job_site = intent.target_object
#		if not "global_position" in job_site:
#			return

		# Check range (MinionTasker has _is_in_work_range but it is private helper)
		# But perform_work_tick checks range internally and returns false if not in range?
		# No, perform_work_tick says "Advisor should have checked range".

		# So we must check range.
		# MinionTasker exposes work_range (float).
#		var range_sq = _tasker.work_range * _tasker.work_range
#		var dist_sq = agent.global_position.distance_squared_to(job_site.get_work_position_for(agent))

#		if dist_sq > range_sq:
#			agent.movement.move_to_position(job_site.get_work_position_for(agent))
#		else:
#			agent.movement.stop() # Stop moving to work
#			_tasker.perform_work_tick()
#
