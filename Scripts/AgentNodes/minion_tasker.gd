extends Node
class_name MinionTasker

# --- CONFIGURATION ---
@export var agent: AgentBase = null # Strict type
@export var movement: AgentMovement = null
@export var castle: Castle = null
@export var work_range: float = 1.0
@export var work_interval: float = 1.0
@export var work_amount: float = 1.0
@export var kind: int = 0 # JobBoardType (int is faster than Enum lookup)
@export var auto_get_work_when_idle: bool = true

var _job_board: Node = null # Generic Node to avoid circular dependency issues
var _site: WorkSite = null

# Optimization: Cache work range squared to avoid math in loop
var _work_range_sq: float = 0.0

func _ready() -> void:
	_work_range_sq = work_range * work_range
	
	# Initial setup
	if agent and not castle:
		if agent.has_method("return_castle"):
			set_castle(agent.return_castle())

func set_castle(new_castle: Castle) -> void:
	if new_castle == castle: return

	_release_job(true)
	_job_board = null # Clear old board

	castle = new_castle
	
	if castle:
		_job_board = castle.return_job_board(kind)
		if _job_board and _job_board.has_method("register_minion"):
			_job_board.register_minion(self)

	# We don't auto request job here anymore, Advisor will do it if idle.

# --- STATE MANAGEMENT ---

func assign_job(site: WorkSite) -> void:
	_release_job(true) # Clear old job
	if not site:
		return

	_site = site
	# We don't command movement here.

func request_job() -> void:
	if not _job_board: return
	
	var site = null
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

	_site = null

# --- WORK LOGIC (Called by Advisor) ---

func perform_work_tick() -> bool:
	if not agent or not _site:
		return false

	if not _site.needs_work():
		_release_job(true)
		return false

	# Advisor should have checked range, but we can double check
	if not _is_in_work_range(_site):
		return false

	_site.apply_work(work_amount, self)

	if _site and not _site.needs_work():
		_release_job(true)
		
	return true

func get_current_job() -> WorkSite:
	return _site

# --- HELPERS ---

func _is_in_work_range(site: WorkSite) -> bool:
	if not agent: return false
	
	var target_pos = site.get_work_position_for(agent)
	return agent.global_position.distance_squared_to(target_pos) <= _work_range_sq

func _on_movement_finished(_agent_node: AgentBase) -> void:
	# No longer needed, Advisor handles state
	pass

# --- COMPATIBILITY / SETTERS ---
func set_agent(a: AgentBase) -> void: agent = a
func set_movement(m: AgentMovement) -> void: movement = m
func clear_task() -> void: _release_job(true)
func has_task() -> bool: return _site != null
func get_agent() -> AgentBase: return agent

func return_position() -> Vector3:
	if agent:
		return agent.global_position
	return Vector3.ZERO

func switch_job_board(c: Castle) -> void:
	set_castle(c)
