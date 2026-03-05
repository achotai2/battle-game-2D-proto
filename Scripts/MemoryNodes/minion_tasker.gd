extends Node
class_name MinionTasker

# --- CONFIGURATION ---
@export var agent: AgentBase = null # Strict type
@export var movement: AgentMovement = null
@export var castle: Castle = null
@export var work_range: float = 1.0
@export var kind: int = 0 # JobBoardType (int is faster than Enum lookup)
@export var auto_get_work_when_idle: bool = true

var _job_board: Node = null # Generic Node to avoid circular dependency issues
var _site: WorkSite = null
var _known_jobs: Array[WorkSite] = []

# Optimization: Cache work range squared to avoid math in loop
var _work_range_sq: float = 0.0

func _ready() -> void:
	_work_range_sq = work_range * work_range
	
	if not is_instance_valid(agent):
		agent = ComponentFinder.get_base(self)

	if is_instance_valid(agent):
		if not agent.new_castle_set.is_connected(set_castle):
			agent.new_castle_set.connect(set_castle)
		if not castle:
			if agent.has_method("return_castle"):
				set_castle(agent.return_castle())

func set_castle(new_castle: Castle) -> void:
	if new_castle == castle: return

	_release_job(true)

	if is_instance_valid(_job_board):
		if _job_board.has_signal("work_available"):
			_job_board.work_available.disconnect(_on_work_available)
		if _job_board.has_signal("work_completed"):
			_job_board.work_completed.disconnect(_on_work_completed)

	_job_board = null # Clear old board
	_known_jobs.clear()

	castle = new_castle
	
	if castle:
		_job_board = castle.return_job_board(kind)
		if is_instance_valid(_job_board):
			if _job_board.has_method("register_minion"):
				_job_board.register_minion(self)
			if _job_board.has_signal("work_available") and not _job_board.work_available.is_connected(_on_work_available):
				_job_board.work_available.connect(_on_work_available)
			if _job_board.has_signal("work_completed") and not _job_board.work_completed.is_connected(_on_work_completed):
				_job_board.work_completed.connect(_on_work_completed)

# --- STATE MANAGEMENT ---

func _on_work_available(site: WorkSite) -> void:
	if not site in _known_jobs:
		_known_jobs.append(site)

func _on_work_completed(site: WorkSite) -> void:
	if site in _known_jobs:
		_known_jobs.erase(site)
	if _site == site:
		_release_job(false)

func get_closest_known_job() -> WorkSite:
	var best_site: WorkSite = null
	var best_dist_sq: float = INF

	if not is_instance_valid(agent): return null

	for i in range(_known_jobs.size() - 1, -1, -1):
		var site = _known_jobs[i]
		if not is_instance_valid(site) or not site.needs_work():
			_known_jobs.remove_at(i)
			continue

		var dist_sq = agent.global_position.distance_squared_to(site.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_site = site

	return best_site

func assign_job(site: WorkSite) -> void:
	_release_job(true) # Clear old job
	if not site:
		return

	_site = site
	# We don't command movement here.


func _release_job(release_to_board: bool) -> void:
	if release_to_board and is_instance_valid(_job_board) and is_instance_valid(_site):
		if _job_board.has_method("release_job"):
			_job_board.release_job(_site, self)
	elif is_instance_valid(_site):
		_site.unreserve(agent)

	_site = null

# --- WORK LOGIC (Called by Advisor) ---
func get_current_job() -> WorkSite:
	return _site

# --- HELPERS ---

# DEPRECIATED
func _is_in_work_range(site: WorkSite) -> bool:
	if not agent: return false
	
	var target_pos = site.get_work_position_for(agent)
	return agent.global_position.distance_squared_to(target_pos) <= _work_range_sq

# DEPRECIATED
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
