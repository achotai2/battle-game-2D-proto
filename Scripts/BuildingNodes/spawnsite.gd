extends WorkSite
class_name SpawnSite
## A WorkSite variant that queues spawn/transform requests and applies roles to peasants.

signal spawn_completed(agent: Node2D, role: StringName, player: int)

@export var spawn_role: UnitRoles.UnitType = UnitRoles.UnitType.SOLDIER
@export var work_per_spawn: float = 5.0
@export var default_player: int = 0
@export var clear_queue_on_disable: bool = false
@export var spawn_location: Marker2D

var _peasants_qeued: int = 0
var _task_work: float = 0.0


func _ready() -> void:
	if kind != CastleJobBoard.JobBoardType.WORKERS:
		kind = CastleJobBoard.JobBoardType.WORKERS
	super._ready()
	total_work = 0.0


func enqueue_spawn(amount: int = 1) -> void:
# When player interacts this gets called.
# Add total_work and queue another peasant.
	if amount <= 0:
		return
		
	if not enabled:
		set_enabled(true)
		reset_progress()
		refresh_registration()
		total_work = 0.0
		_task_work = 0.0
	else:
		refresh_registration()

	total_work += work_per_spawn

func apply_work(amount: float, worker: MinionTasker) -> void:
# Extends the worksite.gd apply work function for spawnsite logic:
	if not enabled or not needs_work():
		return
	
	# Call standard apply_work logic.
	super.apply_work(amount, worker)

	_task_work += amount

	if _task_work >= work_per_spawn:
		_peasants_qeued += 1
		_task_work -= work_per_spawn

		# Get peasant from castle and call them over.
		var _minions: Array = get_parent().castle.get_active_minions()
		for m in _minions:
			if m.is_in_group("Peasants") and m.tactical.call_over(spawn_location.global_position):
				if not m.movement.move_to_pos_finished.is_connected(_peasant_move_finished):
					m.movement.move_to_pos_finished.connect(_peasant_move_finished)
					break
					


func _peasant_move_finished(_peasant: Node2D) -> void:
	_peasants_qeued -= 1
	if _peasants_qeued < 0:
		print_debug("Peasants queud went less than 0")
		_peasants_qeued = 0

	if _peasant.has_method("apply_role"):
		spawn_role = _resolve_spawn_role()
		_peasant.call("apply_role", spawn_role, _resolve_spawn_player())
	else:
		print_debug("peasant does not have function apply_role.")

	if _peasant.movement.move_to_pos_finished.is_connected(_peasant_move_finished):
		_peasant.movement.move_to_pos_finished.disconnect(_peasant_move_finished)

	if not needs_work() and _peasants_qeued <= 0:
		set_enabled(false)


func set_enabled(new_enabled: bool) -> void:
	super.set_enabled(new_enabled)
	if not new_enabled and clear_queue_on_disable:
		_work_done = 0.0
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


func _resolve_agent(minion: MinionTasker) -> Node2D:
	if minion == null:
		return null

	return minion.get_parent()
