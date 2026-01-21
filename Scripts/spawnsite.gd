extends WorkSite
class_name SpawnSite
## A WorkSite variant that queues spawn/transform requests and applies roles to peasants.

signal spawn_completed(agent: Node2D, role: StringName, player: int)

@export var spawn_role: StringName = &""
@export var use_building_config: bool = true
@export var default_player: int = 0
@export var clear_queue_on_disable: bool = true

var _queued_spawns: int = 0


func _ready() -> void:
	if kind != "Peasants":
		kind = "Peasants"
	if total_work <= 0.0:
		total_work = 1.0
	if total_work != 1.0:
		total_work = 1.0
	super._ready()


func enqueue_spawn(amount: int = 1) -> void:
	if amount <= 0:
		return
	_queued_spawns += amount
	if not enabled:
		set_enabled(true)
		reset_progress()
		refresh_registration()
	else:
		refresh_registration()


func needs_work() -> bool:
	if not enabled:
		return false
	return _queued_spawns > 0


func apply_work(amount: float, worker: WorkSiteWorker) -> void:
	if not enabled or not needs_work():
		return
	if _queued_spawns <= 0:
		return

	var safe_amount: float = maxf(amount, 0.0)
	_work_done = minf(total_work, _work_done + safe_amount)

	if _work_done < total_work:
		return

	_queued_spawns = maxi(0, _queued_spawns - 1)
	_apply_role_to_worker(worker)

	if _queued_spawns > 0:
		_work_done = 0.0
		return

	_complete()


func set_enabled(new_enabled: bool) -> void:
	super.set_enabled(new_enabled)
	if not new_enabled and clear_queue_on_disable:
		_queued_spawns = 0
		_work_done = 0.0


func _apply_role_to_worker(worker: WorkSiteWorker) -> void:
	if worker == null or not is_instance_valid(worker):
		return

	var agent := _resolve_agent(worker)
	if agent == null:
		return

	var role := _resolve_spawn_role()
	if role == &"":
		return
	var player_id := _resolve_spawn_player()

	if agent.has_method("apply_role"):
		agent.call("apply_role", role, player_id)
		spawn_completed.emit(agent, role, player_id)


func _resolve_spawn_role() -> StringName:
	if spawn_role != &"":
		return spawn_role
	if use_building_config and is_instance_valid(my_boss):
		var building_type = _get_boss_property(&"building_type")
		if building_type is StringName or building_type is String:
			var config := BuildingDefs.get_spawn_config(StringName(building_type))
			var unit_type := String(config.get("unit_type", ""))
			if unit_type != "":
				return StringName(unit_type.to_lower())
	return &""


func _resolve_spawn_player() -> int:
	if is_instance_valid(my_boss):
		var boss_player = _get_boss_property(&"player")
		if boss_player is int:
			return boss_player
	return default_player


func _get_boss_property(property_name: StringName) -> Variant:
	if my_boss == null:
		return null
	for prop in my_boss.get_property_list():
		if prop.name == property_name:
			return my_boss.get(property_name)
	return null


func _resolve_agent(minion: WorkSiteWorker) -> Node2D:
	if minion == null:
		return null

	if minion.has_method("get_agent"):
		var agent = minion.call("get_agent")
		if agent is Node2D:
			return agent

	for prop in minion.get_property_list():
		if prop.name == &"agent":
			var agent_prop = minion.get("agent")
			if agent_prop is Node2D:
				return agent_prop
			break
	return null
