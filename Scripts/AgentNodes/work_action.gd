extends Node
class_name WorkAction

var _last_work_time: int = 0
var agent: AgentBase = null
var movement: AgentMovement = null
var animate: AgentAnimate = null
var tasker: MinionTasker = null

func _ready() -> void:
	if not agent:
		agent = ComponentFinder.get_base(self)
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")
	if not animate:
		animate = ComponentFinder.get_component(self, "AgentAnimate")
	if not tasker:
		tasker = ComponentFinder.get_component(self, "MinionTasker")

func do_work(job: WorkSite) -> void:
	if not is_instance_valid(job):
		return

	if not is_instance_valid(agent) or not is_instance_valid(tasker):
		return

	var target_pos = job.get_work_position_for(agent)
	var range_sq = tasker.work_range * tasker.work_range
	var dist_sq = agent.global_position.distance_squared_to(target_pos)

	if dist_sq <= range_sq:
		# In range, do work
		if is_instance_valid(movement):
			movement.stop()

		if is_instance_valid(animate):
			animate.play_work()

		var now = Time.get_ticks_msec()
		var interval_ms = int(tasker.work_interval * 1000)
		if now - _last_work_time >= interval_ms:
			if tasker.perform_work_tick():
				_last_work_time = now
	else:
		# Move to work
		if is_instance_valid(movement):
			movement.move_to_position(target_pos)
