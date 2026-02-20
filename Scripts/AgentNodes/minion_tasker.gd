extends Node
class_name MinionTasker

# --- CONFIGURATION ---
@export var agent: AgentBase = null # Strict type
@export var movement: AgentMovement = null
@export var castle: Castle = null
@export var work_range: float = 1.0
@export var work_interval: float = 1.0
@export var work_amount: float = 1.0
@export_range(0.05, 1.0, 0.05) var think_interval: float = 0.5 # Increased default
@export var blast_think: bool = true
@export var kind: int = 0 # JobBoardType (int is faster than Enum lookup)
@export var auto_get_work_when_idle: bool = true

var job_priority: int = 8

enum State { IDLE, MOVING, WORKING }

var _job_board: Node = null # Generic Node to avoid circular dependency issues
var _site: WorkSite = null
var _state: State = State.IDLE
var _think_timer: Timer
var _work_timer: Timer

# Optimization: Cache work range squared to avoid math in loop
var _work_range_sq: float = 0.0

func _ready() -> void:
	_work_range_sq = work_range * work_range

	_think_timer = Timer.new()
	_think_timer.wait_time = think_interval
	_think_timer.timeout.connect(_on_think)
	add_child(_think_timer)
	
	if blast_think:
		_think_timer.start(randf() * think_interval)
	else:
		_think_timer.start()

	_work_timer = Timer.new()
	_work_timer.wait_time = work_interval
	_work_timer.timeout.connect(_on_work_tick)
	add_child(_work_timer)

	# Initial setup
	if agent and not castle:
		# Optimization: Direct access if possible, or reliable call
		if agent.has_method("return_castle"):
			set_castle(agent.return_castle())

func set_castle(new_castle: Castle) -> void:
	if new_castle == castle: return

	_release_job(true)
	_job_board = null # Clear old board

	castle = new_castle
	
	# [OPTIMIZATION] Get board immediately
	if castle:
		_job_board = castle.return_job_board(kind)
		if _job_board and _job_board.has_method("register_minion"):
			_job_board.register_minion(self)

	_set_idle_state()
	_request_job_if_idle()

# --- HOT LOOP: THINK ---

func _on_think() -> void:
	# [OPTIMIZATION] Fast exit if agent died
	if not agent: return

	# [OPTIMIZATION] Don't spam "Get Castle" every frame.
	# Only look for a castle if we are totally lost (no castle ref).
	if not castle and agent.has_method("return_castle"):
		set_castle(agent.return_castle())

	# 1. Validate Current Job
	if not _site:
		if _state != State.IDLE: _set_idle_state()
		_request_job_if_idle()
		return

	# [OPTIMIZATION] Direct boolean check
	if not _site.needs_work():
		_release_job(true)
		_request_job_if_idle()
		return

	# 2. State Logic
	match _state:
		State.MOVING:
			# [CRITICAL FIX] Do NOT call _command_move_to_site() here!
			# It resets pathfinding every 0.25s.
			# Only check range.
			if _is_in_work_range(_site):
				_enter_work_state()
			else:
				# Optional: Check if target moved far? (Only needed for moving targets)
				# For static buildings, we rely on the initial move command.
				pass

		State.WORKING:
			# If we pushed out of range (physics), go back to moving
			if not _is_in_work_range(_site):
				_state = State.MOVING
				_work_timer.stop()
				_command_move_to_site() # Re-issue move command

		State.IDLE:
			_request_job_if_idle()

# --- HOT LOOP: WORK ---

func _on_work_tick() -> void:
	if not agent or not _site:
		_work_timer.stop()
		_set_idle_state()
		return

	# Re-validate
	if not _site.needs_work():
		_release_job(true)
		return

	if not _is_in_work_range(_site):
		_state = State.MOVING
		_work_timer.stop()
		_command_move_to_site() # Re-approach
		return

	# Perform Work
	# [OPTIMIZATION] Direct access if 'site' is strict typed or cached
	_site.apply_work(work_amount, self)

	# Check if finished
	if _site and not _site.needs_work():
		_release_job(true)

# --- STATE MANAGEMENT ---

func assign_job(site: WorkSite) -> void:
	_release_job(true) # Clear old job
	if not site:
		_set_idle_state()
		return

	_site = site
	_state = State.MOVING
	_work_timer.stop()
	
	# [CRITICAL] We command movement ONCE when assigned.
	_command_move_to_site()

func _enter_work_state() -> void:
	if _state == State.WORKING: return
	_state = State.WORKING
	
	if movement:
		movement.command_start_work(job_priority)

	# Do one tick immediately
	_on_work_tick()
	
	if _state == State.WORKING:
		_work_timer.start()

func _set_idle_state() -> void:
	_state = State.IDLE
	_work_timer.stop()
	# Stop moving
	if movement: movement.clear_movement_order(job_priority)

func _request_job_if_idle() -> void:
	if _state != State.IDLE or not _job_board: return
	if auto_get_work_when_idle:
		request_job()

func request_job() -> void:
	if not _job_board: return
	
	var site = null
	# [OPTIMIZATION] Direct calls
	if _job_board.has_method("request_job"):
		site = _job_board.request_job(self)
	elif _job_board.has_method("minion_idle"):
		_job_board.minion_idle(self) # Legacy support
		return

	if site: assign_job(site)

func _release_job(release_to_board: bool) -> void:
	if release_to_board and _job_board and _site:
		if _job_board.has_method("release_job"):
			_job_board.release_job(_site, self)
	elif _site:
		_site.unreserve(agent)

	_set_idle_state()
	_site = null

# --- HELPERS ---

func _command_move_to_site() -> void:
	if not movement or not _site: return
	
	var target_pos = _site.get_work_position_for(agent)
		
	movement.command_move_to_position(target_pos, job_priority)

func _is_in_work_range(site: WorkSite) -> bool:
	if not agent: return false
	
	var target_pos = site.get_work_position_for(agent)
		
	return agent.global_position.distance_squared_to(target_pos) <= _work_range_sq

func _on_movement_finished(_agent_node: AgentBase) -> void:
	if _state == State.MOVING and _site:
		_enter_work_state()

# --- COMPATIBILITY / SETTERS ---
func set_agent(a: AgentBase) -> void: agent = a
func set_movement(m: AgentMovement) -> void: movement = m
func clear_task() -> void: _release_job(true); _set_idle_state()
func has_task() -> bool: return _site != null
func get_agent() -> AgentBase: return agent

func return_position() -> Vector3:
	if agent:
		return agent.global_position
	return Vector3.ZERO
