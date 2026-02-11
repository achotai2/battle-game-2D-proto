extends WorkSiteWorker
class_name MinionTasker

@export var agent: Node2D = null
@export var movement: AgentMovement = null
@export var castle: Node2D = null
@export var work_range: float = 50.0
@export var work_interval: float = 1.0
@export var work_amount: float = 1.0
@export_range(0.05, 1.0, 0.05) var think_interval: float = 0.25
@export var blast_think: bool = true
@export var kind: CastleJobBoard.JobBoardType = CastleJobBoard.JobBoardType.WORKERS
@export var auto_get_work_when_idle: bool = true

var job_priority: int = 8

enum State {
	IDLE,
	MOVING,
	WORKING,
}

var _job_board: CastleJobBoard = null
var _site: Node2D = null
var _state: State = State.IDLE
var _think_timer: Timer
var _work_timer: Timer


func _ready() -> void:
	_think_timer = Timer.new()
	_think_timer.one_shot = false
	_think_timer.wait_time = think_interval
	_think_timer.timeout.connect(_on_think)
	add_child(_think_timer)
	if blast_think:
		_think_timer.start(randf() * think_interval)
	else:
		_think_timer.start()

	_work_timer = Timer.new()
	_work_timer.one_shot = false
	_work_timer.wait_time = work_interval
	_work_timer.timeout.connect(_on_work_tick)
	add_child(_work_timer)

	if is_instance_valid(agent) and agent.has_method("return_castle"):
		set_castle(agent.call("return_castle"))
	elif is_instance_valid(castle):
		set_castle(castle)


func set_agent(my_agent: Node2D) -> void:
	agent = my_agent
	if is_instance_valid(agent) and agent.has_method("return_castle"):
		set_castle(agent.call("return_castle"))
	else:
		print_debug("agent does not have function return_castle.")


func set_movement(m: AgentMovement) -> void:
	movement = m


func set_castle(new_castle: Node2D) -> void:
	if new_castle == castle:
		return

	_release_job(true)
	_unregister_from_board()

	castle = new_castle
	_job_board = _resolve_job_board(castle)
	if is_instance_valid(_job_board):
		if _job_board.has_method("register_minion"):
			_job_board.call("register_minion", self)
		else:
			print_debug("job_board does not have function register_minion.")

	_state = State.IDLE
	_request_job_if_idle()


func switch_job_board(new_castle: Node2D) -> void:
	set_castle(new_castle)


func clear_task() -> void:
	_release_job(true)
	_set_idle_state()


func has_task() -> bool:
	return is_instance_valid(_site)


func get_agent() -> Node2D:
	return agent


func return_position() -> Vector2:
	if is_instance_valid(agent):
		if agent.has_method("return_position"):
			return agent.call("return_position")
		else:
			print_debug("agent does not have function return_positon.")

		return agent.global_position
	return Vector2.ZERO


func assign_job(site: Node2D) -> void:
	_release_job(true)
	if site == null or not is_instance_valid(site):
		_set_idle_state()
		return

	_site = site
	_state = State.MOVING
	_work_timer.stop()
	_command_move_to_site()


func _on_think() -> void:
	if agent == null or not is_instance_valid(agent):
		return

	if not is_instance_valid(_job_board) and agent.has_method("return_castle"):
		set_castle(agent.call("return_castle"))

	if _site == null or not is_instance_valid(_site):
		_set_idle_state()
		_request_job_if_idle()
		return

	if not _site_needs_work(_site):
		_release_job(true)
		_set_idle_state()
		_request_job_if_idle()
		return

	match _state:
		State.MOVING:
			_command_move_to_site()
			if _is_in_work_range(_site):
				_enter_work_state()
		State.WORKING:
			if not _is_in_work_range(_site):
				_state = State.MOVING
				_work_timer.stop()
		State.IDLE:
			_request_job_if_idle()


func _on_work_tick() -> void:
	if agent == null or not is_instance_valid(agent):
		_work_timer.stop()
		return

	if _site == null or not is_instance_valid(_site):
		_work_timer.stop()
		_set_idle_state()
		return

	if not _site_needs_work(_site):
		_release_job(true)
		_set_idle_state()
		return

	if not _is_in_work_range(_site):
		_state = State.MOVING
		_work_timer.stop()
		return

	if is_instance_valid(movement) and movement.start_work():
		_apply_work(_site, work_amount)

	if not _site_needs_work(_site):
		_release_job(true)
		_set_idle_state()


func _enter_work_state() -> void:
	if _state == State.WORKING:
		return

	_state = State.WORKING

	_on_work_tick()

	if _state == State.WORKING and _work_timer.is_stopped():
		_work_timer.start()


func _set_idle_state() -> void:
	_state = State.IDLE
	_work_timer.stop()

	if is_instance_valid(movement):
		movement.clear_movement_order(job_priority)


func _request_job_if_idle() -> void:
	if _state != State.IDLE:
		return
	if not is_instance_valid(_job_board):
		return

	if auto_get_work_when_idle:
		request_job()


func request_job() -> void:
	var site: Node2D = null
	if _job_board.has_method("request_job"):
		site = _job_board.request_job(self)
	elif _job_board.has_method("minion_idle"):
		_job_board.minion_idle(self)
		return

	if site != null and is_instance_valid(site):
		assign_job(site)


func _command_move_to_site() -> void:
	if not is_instance_valid(movement):
		return
	movement.command_move_to_position(_get_work_position(_site), job_priority)


func _release_job(release_to_board: bool) -> void:
	if release_to_board and is_instance_valid(_job_board) and is_instance_valid(_site):
		_job_board.release_job(_site, self)
	elif is_instance_valid(_site) and _site.has_method("unreserve"):
		_site.call("unreserve", agent)

	_set_idle_state()
	_site = null
	_work_timer.stop()


func _resolve_job_board(new_castle: Node2D) -> CastleJobBoard:
	if new_castle == null or not is_instance_valid(new_castle):
		return null 

	return new_castle.return_job_board(kind)


func _unregister_from_board() -> void:
	if is_instance_valid(_job_board):
		if _job_board.has_method("unregister_minion"):
			_job_board.call("unregister_minion", self)
		else:
			print_debug("_job_board does not have function unregister_minion.")
	_job_board = null
	_set_idle_state()


func _get_work_position(site: Node2D) -> Vector2:
	if site != null and site.has_method("get_work_position_for"):
		return site.call("get_work_position_for", agent)
	else:
		print_debug("site does not have function get_work_position_for")

	if site != null and site.has_method("get_work_position"):
		return site.call("get_work_position")
	else:
		print_debug("site does not have function get_work_position")

	return agent.global_position if is_instance_valid(agent) else Vector2.ZERO


func _apply_work(site: Node2D, amount: float) -> void:
	if site != null and site.has_method("apply_work"):
		site.call("apply_work", amount, self)


func _site_needs_work(site: Node2D) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	if site.has_method("needs_work"):
		return bool(site.call("needs_work"))
	return true


func _is_in_work_range(site: Node2D) -> bool:
	if not is_instance_valid(agent):
		return false
	var wp := _get_work_position(site)
	return agent.global_position.distance_squared_to(wp) <= (work_range * work_range)
