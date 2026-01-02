extends Node
class_name TacticalWorker
## Simple worker tactics (no combat):
## - If idle: request a work site from its castle's JobBoard (if present).
## - Move to the site's work position.
## - When in range: "work" (swing) every work_interval seconds and apply work to the site.
## - If site completes or becomes invalid: request a new one.
##
## Assumptions about your world:
## - AgentBase will connect these signals to pathfinding:
##     move_to_position(Vector2) -> pathfinding.set_move_target_position(pos)
##     resume_patrol() -> pathfinding.set_meander(true) (optional)
## - Your castle provides a job board node with method:
##     request_job(worker: Node2D) -> Node2D (a site)
## - A site supports:
##     get_work_position() -> Vector2   (or has method "return_position" as fallback)
##     apply_work(amount: float, worker: Node2D) -> void
##     needs_work() -> bool (optional)
##
## You can tighten these interfaces later.

signal move_to_position(pos: Vector2)
signal resume_patrol()

@export var work_range: float = 28.0
@export var work_interval: float = 0.35
@export var work_amount_per_hit: float = 1.0

@export_range(0.05, 1.0, 0.05) var think_interval: float = 0.25
@export_range(0.0, 1.0, 0.05) var retarget_cooldown: float = 0.25

var _agent: Node2D
var _castle: Node2D
var _job_board: Node = null

var _site: Node2D = null
var _think_timer: Timer
var _work_timer: Timer
var _last_assign_time: float = -999.0


func _ready() -> void:
	_agent = get_parent() as Node2D
	if _agent == null:
		push_warning("TacticalWorker must be a child of the agent (Node2D).")

	_think_timer = Timer.new()
	_think_timer.one_shot = false
	_think_timer.wait_time = think_interval
	_think_timer.timeout.connect(_on_think)
	add_child(_think_timer)

	_work_timer = Timer.new()
	_work_timer.one_shot = false
	_work_timer.wait_time = work_interval
	_work_timer.timeout.connect(_on_work_tick)
	add_child(_work_timer)

	# Start thinking (stagger to avoid all workers syncing)
	_think_timer.start(randf() * think_interval)


# Called by AgentBase after role assignment
func set_castle(castle: Node) -> void:
	_castle = castle as Node2D
	_job_board = _resolve_job_board(_castle)

	# If we were mid-task but castle changed, drop and re-request
	_clear_site()
	_request_job()


func clear_task() -> void:
	_clear_site()
	resume_patrol.emit()


func has_task() -> bool:
	return is_instance_valid(_site)


# -------------------------
# Core loop
# -------------------------

func _on_think() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return

	# No castle / job board -> nothing to do
	if _castle == null or not is_instance_valid(_castle) or _job_board == null:
		return

	# If no current site, try to get one
	if _site == null or not is_instance_valid(_site) or not _site_needs_work(_site):
		_request_job()
		return

	# Move toward work position if not in range
	var wp := _get_work_position(_site)
	var dist2 := _agent.global_position.distance_squared_to(wp)
	if dist2 > (work_range * work_range):
		# While moving, don't spam; just re-emit occasionally via think timer
		move_to_position.emit(wp)
		_work_timer.stop()
	else:
		# In range -> begin/continue working
		if _work_timer.is_stopped():
			_work_timer.start()


func _on_work_tick() -> void:
	if _agent == null or not is_instance_valid(_agent):
		_work_timer.stop()
		return
	if _site == null or not is_instance_valid(_site) or not _site_needs_work(_site):
		_work_timer.stop()
		_clear_site()
		_request_job()
		return

	# Still in range?
	var wp := _get_work_position(_site)
	if _agent.global_position.distance_squared_to(wp) > (work_range * work_range):
		_work_timer.stop()
		return

	# Apply work (one "hammer hit")
	_apply_work(_site, work_amount_per_hit)

	# If completed, move on quickly
	if not _site_needs_work(_site):
		_work_timer.stop()
		_clear_site()
		_request_job()


# -------------------------
# Job requesting
# -------------------------

func _request_job() -> void:
	# Avoid thrashing (optional)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_assign_time < retarget_cooldown:
		return
	_last_assign_time = now

	if _job_board == null or not is_instance_valid(_job_board):
		return
	if not _job_board.has_method("request_job"):
		push_warning("Castle job board missing request_job(worker) -> site.")
		return

	var site = _job_board.call("request_job", _agent)
	if site == null or not (site is Node2D):
		# No jobs available
		_site = null
		_work_timer.stop()
		resume_patrol.emit()
		return

	_site = site as Node2D
	# Immediately start moving to it
	move_to_position.emit(_get_work_position(_site))


func _clear_site() -> void:
	_site = null
	_work_timer.stop()


# -------------------------
# WorkSite helpers (loose interface)
# -------------------------

func _get_work_position(site: Node2D) -> Vector2:
	if site.has_method("get_work_position"):
		return site.call("get_work_position")
	# fallback: some of your nodes use return_position()
	if site.has_method("return_position"):
		return site.call("return_position")
	return site.global_position


func _apply_work(site: Node2D, amount: float) -> void:
	if site.has_method("apply_work"):
		site.call("apply_work", amount, _agent)
	elif site.has_method("take_work"):
		site.call("take_work", amount, _agent)
	else:
		# No API; nothing happens
		pass


func _site_needs_work(site: Node2D) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	if site.has_method("needs_work"):
		return bool(site.call("needs_work"))
	# If no needs_work(), assume it always needs work until freed
	return true


func _resolve_job_board(castle: Node2D) -> Node:
	if castle == null or not is_instance_valid(castle):
		return null
	# Convention 1: castle has exported var job_board
	if castle.has_method("get_job_board"):
		return castle.call("get_job_board")
	if castle.has_node("JobBoard"):
		return castle.get_node("JobBoard")
	# Convention 2: castle itself implements request_job
	if castle.has_method("request_job"):
		return castle
	return null
