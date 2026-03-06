extends WorkSite
class_name SpawnSite
## A WorkSite variant that queues spawn/transform requests and applies roles to peasants.

signal spawn_completed(agent: AgentBase, role: StringName, player: int)

@export var spawn_role: UnitRoles.UnitType = UnitRoles.UnitType.SOLDIER
@export var work_per_spawn: float = 5.0
@export var default_player: int = 0
@export var clear_queue_on_disable: bool = false
@export var spawn_location: Marker2D

var _peasants_qeued: int = 0


func _ready() -> void:
	if kind != CastleJobBoard.JobBoardType.PEASANTS:
		kind = CastleJobBoard.JobBoardType.PEASANTS
	super._ready()
	total_work = 0.0


func needs_work() -> bool:
	if not enabled:
		return false

	return _peasants_qeued > 0 and has_free_slot()


func get_slot_count() -> int:
	return _peasants_qeued if _peasants_qeued > 0 else 1


func enqueue_spawn(amount: int = 1) -> void:
# When player interacts this gets called.
# Queue another peasant.
	if amount <= 0:
		return
		
	if not enabled:
		set_enabled(true)
		refresh_registration()
	else:
		refresh_registration()

	_peasants_qeued += amount


func transform_worker(agent: AgentBase) -> void:
	if not enabled or _peasants_qeued <= 0:
		return

	_peasants_qeued -= 1
	release_worker(agent)

	if agent.has_method("apply_role"):
		spawn_role = _resolve_spawn_role()
		agent.call("apply_role", spawn_role, _resolve_spawn_player())
	else:
		print_debug("peasant does not have function apply_role.")

	if _peasants_qeued <= 0:
		set_enabled(false)


func set_enabled(new_enabled: bool) -> void:
	super.set_enabled(new_enabled)
	if not new_enabled and clear_queue_on_disable:
		_peasants_qeued = 0


func _resolve_spawn_role() -> UnitRoles.UnitType:
	var building_type := _get_boss_property()
	var config := BuildingDefs.get_spawn_config(building_type)
	var unit_type: UnitRoles.UnitType = config.get("unit_type", "")
	return unit_type


func _resolve_spawn_player() -> int:
	return get_parent().player


func _get_boss_property() -> BuildingDefs.BuildingType:
	return get_parent().building_type


func _resolve_agent(minion: MinionTasker) -> AgentBase:
	if minion == null:
		return null

	return minion.get_parent()
