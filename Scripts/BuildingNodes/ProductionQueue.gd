extends Node
class_name ProductionQueue

@export var spawnInteractable: Interactable
@export var spawn_worksite: WorkSite
@export var spawn_site: SpawnSite

# We split the queue in two! One for workers, one for peasants.
var _work_queue: Array[UnitRoles.UnitType] = []
var _spawn_queue: Array[UnitRoles.UnitType] = []

var _is_working: bool = false
var _is_spawning: bool = false

# Cached variable so we only look it up once!
var _produced_unit_type: UnitRoles.UnitType


func activate() -> void:
	set_process(true)

func deactivate() -> void:
	set_process(false)


func _ready() -> void:
	# 1. OPTIMIZATION: Figure out what this building makes exactly once.
	var boss = ComponentFinder.get_base(self)
	var config = BuildingDefs.get_spawn_config(boss.building_type)
	_produced_unit_type = config.get("unit_type", UnitRoles.UnitType.WORKER)
	
	# 2. Wire up the signals
	if spawnInteractable:
		spawnInteractable.interaction_finished.connect(_on_player_queued_unit)
	if spawn_worksite:
		spawn_worksite.work_completed.connect(_on_workers_finished)
	if spawn_site:
		# Assuming your SpawnSite emits this when the peasant arrives
		spawn_site.unit_transformed.connect(_on_peasant_transformed)


# --- PIPELINE INTAKE: THE PLAYER CLICKS ---

func _on_player_queued_unit(interactor: AgentBase) -> void:
	# Add the cached unit directly to the worker's to-do list
	_work_queue.append(_produced_unit_type)
	print("Added to Work Queue. Total: ", _work_queue.size())
	
	_process_work_queue()


# --- STAGE 1: THE WORKERS (THE PRODUCERS) ---

func _process_work_queue() -> void:
	# If workers are already busy, or there is no work, do nothing.
	if _is_working or _work_queue.is_empty():
		return
		
	_is_working = true
	
	# Peek at the current unit and set the cost
	var current_unit = _work_queue[0]
	spawn_worksite.total_work = BuildingDefs.get_unit_train_cost(current_unit)
	
	# Wake up the WorkSite!
	spawn_worksite.reset_progress()
	spawn_worksite.set_enabled(true)
	spawn_worksite.refresh_registration()


func _on_workers_finished(site: WorkSite, worker: AgentBase) -> void:
	# Turn off the worksite temporarily
	spawn_worksite.set_enabled(false)
	_is_working = false
	
	# Move the finished unit from the Work Queue to the Spawn Queue
	var finished_unit = _work_queue.pop_front()
	_spawn_queue.append(finished_unit)
	print("Work finished! Moving to Spawn Queue. Total ready to spawn: ", _spawn_queue.size())
	
	# IMMEDIATELY restart the workers if there is more in their queue!
	_process_work_queue()
	
	# Tell the SpawnSite it has a new job to do
	_process_spawn_queue()


# --- STAGE 2: THE SPAWN SITE (THE CONSUMERS) ---

func _process_spawn_queue() -> void:
	# If we are already waiting for a Peasant, or no units are ready, do nothing.
	if _is_spawning or _spawn_queue.is_empty():
		return
		
	_is_spawning = true
	
	# Wake up the SpawnSite to call a Peasant over
	spawn_site.set_enabled(true)
	# (Assuming you add a ping method to your SpawnSite)
	spawn_site.request_peasant() 


func _on_peasant_transformed(new_unit: AgentBase) -> void:
	# The Peasant arrived! Turn off the spawn site temporarily
	spawn_site.set_enabled(false)
	_is_spawning = false
	
	# Pop the unit out of the Spawn Queue and apply the role
	var unit_to_apply = _spawn_queue.pop_front()
	var base = ComponentFinder.get_base(self)
	var team_memory = base.get("team") if base.get("team") else base.get("team_memory")
	var my_team = team_memory.return_team() if team_memory else 0

	new_unit.apply_role(unit_to_apply, my_team)
	
	# IMMEDIATELY call the next Peasant if there are more waiting in line!
	_process_spawn_queue()
