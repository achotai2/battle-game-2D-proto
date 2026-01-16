extends Node
class_name TacticalWorker

signal move_to_position(pos: Vector2)
signal resume_patrol()

@export var work_range: float = 100.0
@export var work_interval: float = 1.00
@export var work_amount_per_hit: float = 1.0
@export var blast_think: bool = true

@export_range(0.05, 1.0, 0.05) var think_interval: float = 1.0
@export var movement: AgentMovement = null
@export var animation: AgentAnimate = null

var _agent: Node2D

var _job_board: CastleJobBoard = null

var _site: WorkSite = null

var _think_timer: Timer
var _work_timer: Timer


func _ready() -> void:
	_think_timer = Timer.new()
	_think_timer.one_shot = false
	_think_timer.wait_time = think_interval
	_think_timer.timeout.connect(_on_think)
	add_child(_think_timer)
	if blast_think:
		_think_timer.start(randf() * think_interval) # stagger
	else:
		_think_timer.stop()

	_work_timer = Timer.new()
	_work_timer.one_shot = false
	_work_timer.wait_time = work_interval
	_work_timer.timeout.connect(_on_work_tick)
	add_child(_work_timer)


# -------------------------
# Called by AgentBase / role system
# -------------------------

func set_agent(my_agent: Node2D) -> void:
	_agent = my_agent

	# Get job board.
	if _agent.has_method("return_castle"):
		switch_job_board(_agent.call("return_castle"))

	# If we have no board, just idle/patrol
	if _job_board == null:
		_clear_site(true)
		_resume_patrol()
		return

	# Immediately announce we're idle to get a job assigned
	notify_idle()


func clear_task() -> void:
	_clear_site(true)
	_resume_patrol()
	notify_idle()


func has_task() -> bool:
	return is_instance_valid(_site)


# JobBoard calls this (push assignment)
func assign_job(site: WorkSite) -> void:
	# Drop previous job (release reservation)
	_clear_site(true)

	if site == null or not is_instance_valid(site):
		notify_idle()
		return

	_site = site
	_work_timer.stop()
	_move_to_position(_get_work_position(_site))


# Worker -> board: "I'm available"
func notify_idle() -> void:
	if is_instance_valid(_job_board):
		_job_board.minion_idle(self)



func return_position() -> Vector2:
	if _agent.has_method("return_position"):
		return _agent.return_position()
	else:
		return Vector2.ZERO


# -------------------------
# Core loop (movement + working once assigned)
# -------------------------

func _on_think() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	# If no job board, request it again to see if one has resolved.
	if not is_instance_valid(_job_board) and _agent.has_method("return_castle"):
		switch_job_board(_agent.call("return_castle"))

	# If no job, keep advertising idle occasionally (in case board missed it)
	if _site == null or not is_instance_valid(_site):
		_work_timer.stop()
		_ensure_patrol()
		notify_idle()
		return

	# If site no longer needs work, release and ask for new
	if not _site_needs_work(_site):
		_clear_site(true)
		notify_idle()
		return

	# Move toward site if not in range
	var wp := _get_work_position(_site)
	if _agent.return_position().distance_squared_to(wp) > (work_range * work_range):
		_move_to_position(wp)
		_work_timer.stop()
	else:
		_halt_movement_for_work()
		if _work_timer.is_stopped():
			_work_timer.start()


func _on_work_tick() -> void:
	if _agent == null or not is_instance_valid(_agent):
		_work_timer.stop()
		return

	if _site == null or not is_instance_valid(_site):
		_work_timer.stop()
		notify_idle()
		return

	if not _site_needs_work(_site):
		_work_timer.stop()
		_clear_site(true)
		notify_idle()
		return

	# Still in range?
	var wp := _get_work_position(_site)
	if _agent.return_position().distance_squared_to(wp) > (work_range * work_range):
		_work_timer.stop()
		return

	# Apply one "hit"
	_apply_work(_site, work_amount_per_hit)

	# Freeze movement while work animation runs.
	_halt_movement_for_work()
	if is_instance_valid(movement):
		movement.start_work()
	elif is_instance_valid(_agent.movement):
		_agent.movement.start_work()

	# If completed, release and request another
	if not _site_needs_work(_site):
		_work_timer.stop()
		_clear_site(true)
		notify_idle()


# Called by agent when castle changes.
func switch_job_board(new_castle: Node2D) -> void:
	# Release any current job before switching
	_clear_site(true)

	# Unregister from old board
	if is_instance_valid(_job_board):
		_job_board.unregister_minion(self)

	_job_board = _resolve_job_board(new_castle)

	# Register with new board
	if is_instance_valid(_job_board):
		_job_board.register_minion(self)

	# Immediately announce we're idle to get a job assigned
	notify_idle()


# -------------------------
# Internals
# -------------------------

func _clear_site(release_to_board: bool) -> void:
	if release_to_board and is_instance_valid(_job_board) and is_instance_valid(_site):
		_job_board.release_job(_site, self)

	_site = null
	_work_timer.stop()


func _resolve_job_board(castle: Node2D) -> CastleJobBoard:
	if castle == null or not is_instance_valid(castle):
		return null

	# Preferred: child node named JobBoard
	else:
		return castle.return_job_board()


# -------------------------
# WorkSite helpers (loose interface)
# -------------------------

func _get_work_position(site: WorkSite) -> Vector2:
	return site.get_work_position()


func _apply_work(site: WorkSite, amount: float) -> void:
	site.apply_work(amount, self)		# Let site know work has been applied.


func _site_needs_work(site: WorkSite) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	return bool(site.needs_work())


func _move_to_position(pos: Vector2) -> void:
	if is_instance_valid(movement):
		movement.command_move_to_position(pos, 5)
	move_to_position.emit(pos)


func _resume_patrol() -> void:
	if is_instance_valid(movement):
		movement.clear_movement_order(6)
	resume_patrol.emit()


func _halt_movement_for_work() -> void:
	if is_instance_valid(movement):
		movement.clear_movement_order(6)


func _ensure_patrol() -> void:
	if is_instance_valid(movement):
		_resume_patrol()
