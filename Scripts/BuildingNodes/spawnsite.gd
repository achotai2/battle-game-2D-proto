extends Node3D
class_name SpawnSite
## A dedicated site that requests a single Peasant from the CastleJobBoard.
## When the Peasant arrives and "works", it emits a signal for the ProductionQueue to transform them.

signal unit_transformed(agent: AgentBase)

@export var my_boss: Node3D = null
@export var spawn_location: Marker3D = null ## Note: Changed to Marker3D for 3D space!

var enabled: bool = false
var kind: CastleJobBoard.JobBoardType = CastleJobBoard.JobBoardType.PEASANTS
var _job_board: CastleJobBoard = null
var _incoming_peasant: AgentBase = null

func activate() -> void:
	set_enabled(true)

func deactivate() -> void:
	set_enabled(false)

func _ready() -> void:
	if not my_boss:
		# Use singleton, or fallback to parent if the singleton misses it
		if has_node("/root/ComponentFinder"): 
			my_boss = ComponentFinder.get_base(self)
		if not my_boss:
			my_boss = get_parent()

	# --- NEW: Listen for Castle changes! ---
	if is_instance_valid(my_boss) and my_boss.has_signal("new_castle_set"):
		if not my_boss.is_connected("new_castle_set", _on_new_castle_set):
			my_boss.connect("new_castle_set", _on_new_castle_set)


# -------------------------
# API FOR PRODUCTION QUEUE
# -------------------------

func request_peasant() -> void:
	# Called by ProductionQueue when the workers finish hammering
	enabled = true
	_incoming_peasant = null
	_resolve_castle_and_register()


func set_enabled(new_enabled: bool) -> void:
	if enabled == new_enabled:
		return
	enabled = new_enabled
	
	if not enabled:
		_unregister_from_job_board()
		_incoming_peasant = null
	else:
		_resolve_castle_and_register()


# -------------------------
# API FOR JOB BOARD & AI
# -------------------------

func needs_work() -> bool:
	return enabled


func has_free_slot() -> bool:
	return _incoming_peasant == null


func assign_worker(agent: AgentBase) -> bool:
	if not enabled or not has_free_slot() or agent == null:
		return false
		
	_incoming_peasant = agent
	return true


func release_worker(agent: AgentBase) -> void:
	if _incoming_peasant == agent:
		_incoming_peasant = null


func get_work_position() -> Vector3:
	if spawn_location:
		return spawn_location.global_position
	return global_position


func get_work_position_for(_agent: AgentBase) -> Vector3:
	return get_work_position()


func transform_worker(agent: AgentBase) -> void:
	apply_work(1.0, agent)


func apply_work(_amount: float, worker: AgentBase) -> void:
	if worker != _incoming_peasant or not enabled:
		return

	_unregister_from_job_board()
	enabled = false
	_incoming_peasant = null

	unit_transformed.emit(worker)


# -------------------------
# INTERNALS: REGISTRATION & SIGNALS
# -------------------------

# --- NEW: The Signal Handler ---
func _on_new_castle_set(new_castle: Node) -> void:
	if not new_castle is Castle:
		return
		
	# 1. Unregister from the old board immediately
	_unregister_from_job_board()
	
	# 2. Cache the new job board (even if we don't need a peasant right now)
	if new_castle.has_method("return_job_board"):
		_job_board = new_castle.call("return_job_board", kind)
	
	# 3. If we ARE actively waiting for a peasant, post the job to the new Castle!
	if enabled and is_instance_valid(_job_board):
		_job_board.register_site(self)


func _resolve_castle_and_register() -> void:
	_unregister_from_job_board()

	var _castle: Node = null
	if is_instance_valid(my_boss) and my_boss.has_method("return_castle"):
		_castle = my_boss.call("return_castle")

	if not _castle is Castle: 
		return

	# Cache the board
	if _castle.has_method("return_job_board"):
		_job_board = _castle.call("return_job_board", kind)
		
	# Register if active
	if enabled and is_instance_valid(_job_board):
		_job_board.register_site(self)


func _unregister_from_job_board() -> void:
	if is_instance_valid(_job_board):
		_job_board.unregister_site(self)
	_job_board = null


func _exit_tree() -> void:
	_unregister_from_job_board()
