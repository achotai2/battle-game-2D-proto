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

func _ready() -> void:
	if not my_boss:
		my_boss = ComponentFinder.get_base(self)


# -------------------------
# API FOR PRODUCTION QUEUE
# -------------------------

func request_peasant() -> void:
	# Called by ProductionQueue when the workers finish hammering
	enabled = true
	_incoming_peasant = null
	_resolve_castle_and_register()


func set_enabled(new_enabled: bool) -> void:
	enabled = new_enabled
	if not enabled:
		_unregister_from_job_board()
		_incoming_peasant = null


# -------------------------
# API FOR JOB BOARD & AI
# -------------------------

func needs_work() -> bool:
	# We only need a peasant if we are enabled and haven't claimed one yet
	return enabled and _incoming_peasant == null


func assign_worker(agent: AgentBase) -> bool:
	if not needs_work() or agent == null:
		return false
		
	# Claim this peasant so the Job Board doesn't send 5 peasants for 1 job!
	_incoming_peasant = agent
	return true


func release_worker(agent: AgentBase) -> void:
	if _incoming_peasant == agent:
		_incoming_peasant = null


func get_work_position() -> Vector3:
	# Tell the Peasant where to walk
	if spawn_location:
		return spawn_location.global_position
	return global_position


func apply_work(_amount: float, worker: AgentBase) -> void:
	## In the AI's mind, it is "working", but for a Peasant, arriving IS the work.
	if worker != _incoming_peasant or not enabled:
		return

	# We got our peasant! Shut down the site.
	_unregister_from_job_board()
	enabled = false
	_incoming_peasant = null

	# Tell the ProductionQueue to apply the specific role!
	unit_transformed.emit(worker)


# -------------------------
# INTERNALS: REGISTRATION
# -------------------------

func _resolve_castle_and_register() -> void:
	if not enabled: 
		return
	_unregister_from_job_board()

	var _castle: Node = null
	if is_instance_valid(my_boss) and my_boss.has_method("return_castle"):
		_castle = my_boss.call("return_castle")

	if _castle == null: 
		return

	if _castle.has_method("return_job_board"):
		_job_board = _castle.call("return_job_board", kind)
		if is_instance_valid(_job_board):
			_job_board.register_site(self)


func _unregister_from_job_board() -> void:
	if is_instance_valid(_job_board):
		_job_board.unregister_site(self)
	_job_board = null


func _exit_tree() -> void:
	_unregister_from_job_board()
