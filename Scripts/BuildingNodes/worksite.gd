extends Node2D
class_name WorkSite
## A reusable "work target" that workers can be assigned to by a CastleJobBoard.
##
## Intended usage:
## - This node is a *child* of some parent object (building, tree, construction site, repair target).
## - The parent object stores a reference to its castle (Node2D).
## - This WorkSite finds the castle by calling parent.get_castle() (preferred) or reading parent.castle (fallback).
## - It registers itself with the castle’s JobBoard (CastleJobBoard) so workers can be assigned here.
##
## Workers will:
## - Move to get_work_position_for(agent) when available (or get_work_position fallback)
## - While in range, call apply_work(amount, worker)
## - When completed, this WorkSite unregisters itself and emits work_completed.


# Emitted once, when total work has been completed.
signal work_completed(site: WorkSite, worker: MinionTasker)

# Emitted when work is applied to site.
signal work_applied(site: WorkSite)

# -------------------------
# Editor / tuning variables
# -------------------------

@export var my_boss: Node2D = null
## Cached parent reference.

@export var total_work: float = 10.0
## How much "work" is required before the site is considered complete.
## Example meanings:
## - build progress to finish a construction
## - repair progress to fix something
## - chopping progress to fell a tree

@export var auto_register: bool = true
## If true, the WorkSite automatically resolves its castle and registers with the job board in _ready().
## If false, you can call refresh_registration() manually after setting up parent/castle references.

@export var work_offset: Marker2D = null
## Optional offset (in global space) where workers should stand to work.
## Useful if the building's sprite origin isn't where you want workers to path to.

@export var enabled: bool = true
## Whether this WorkSite is currently active and available for workers.

## References the group that the minion is a part of who will match this worksite.
@export var kind: CastleJobBoard.JobBoardType = CastleJobBoard.JobBoardType.WORKERS

# -------------------------
# Runtime state
# -------------------------

var _work_done: float = 0.0
## Current accumulated work.

var _job_board: CastleJobBoard = null
## Cached job board reference resolved from castle. We keep it so we can unregister cleanly.

var _slot_markers: Array[Marker2D] = []
var _slot_for_agent: Dictionary = {} # agent: slot_index
var _agent_for_slot: Dictionary = {} # slot_index: agent


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	## Called when the node enters the scene tree.
	## If auto_register is enabled, we locate the castle/job board and register this site as available work.
	_collect_slots()
	if auto_register and enabled:
		_resolve_castle_and_register()


func _exit_tree() -> void:
	## Called when the node is removed from the scene tree (freed, scene changed, etc).
	## We attempt to unregister from the job board to avoid stale entries.
	_unregister_from_job_board()


# -------------------------
# Public API (used by workers / job board)
# -------------------------

func needs_work() -> bool:
	## Returns whether this work site still requires work.
	## The JobBoard uses this to decide if the job is still valid.
	if not enabled:
		return false
		
	return _work_done < total_work


func get_work_position() -> Vector2:
	## Returns the world position a worker should move to in order to work on this site.
	## Workers will typically stand near this position and repeatedly call apply_work().
	if not is_instance_valid(my_boss) or not my_boss.has_method("return_position"):
		return Vector2.ZERO

	var base_pos: Vector2 = my_boss.return_position()
	if is_instance_valid(work_offset):
		return base_pos + work_offset.position
	return base_pos


func get_slot_count() -> int:
	return _slot_markers.size() if _slot_markers.size() > 0 else 1


func has_free_slot() -> bool:
	_cleanup_invalid_agents()
	if _slot_markers.is_empty():
		return not _agent_for_slot.has(0)
	return _agent_for_slot.size() < _slot_markers.size()


func can_reserve(agent: Node2D) -> bool:
	## Optional hook: JobBoard can ask if this site can be reserved by a given agent.
	if not needs_work():
		return false

	_cleanup_invalid_agents()
	if agent != null and _slot_for_agent.has(agent):
		return true
	return has_free_slot()


func reserve(agent: Node2D) -> bool:
	## Optional hook: JobBoard calls this when it assigns/reserves the job for an agent.
	if agent == null or not is_instance_valid(agent):
		return false
	if not needs_work():
		return false

	_cleanup_invalid_agents()
	if _slot_for_agent.has(agent):
		return true

	var slot_index := _find_free_slot_index()
	if slot_index == -1:
		return false

	_assign_slot(agent, slot_index)
	return true


func unreserve(agent: Node2D) -> void:
	## Optional hook: JobBoard calls this when releasing the reservation (worker changed jobs, etc.)
	if agent == null:
		return
	if not _slot_for_agent.has(agent):
		return

	var slot_index: int = _slot_for_agent[agent]
	_slot_for_agent.erase(agent)
	_agent_for_slot.erase(slot_index)


func get_work_position_for(agent: Node2D) -> Vector2:
	## Returns the per-agent work position (slot) if reserved.
	_cleanup_invalid_agents()
	if agent != null and _slot_for_agent.has(agent):
		return _get_slot_position(_slot_for_agent[agent])

	if _slot_markers.is_empty():
		return global_position

	var free_index := _find_free_slot_index()
	if free_index != -1:
		return _get_slot_position(free_index)
	return _get_slot_position(0)


func apply_work(amount: float, worker: MinionTasker) -> void:
	## Called by a worker to contribute progress toward completion.
	## - amount: how much work this "hit" contributes
	## - worker: the worker doing the work (useful if you want to attribute credit)
	##
	## This function:
	## - ignores work if already completed
	## - clamps negative work to 0
	## - completes the site once total_work reached
	if not enabled or not needs_work():
		_complete(worker)
		return

	var safe_amount: float = maxf(amount, 0.0)
	_work_done = minf(total_work, _work_done + safe_amount)

	# DISABLED GIVING GOLD TO WORKER.
#	if is_instance_valid(get_parent().gold):
#		var amount_to_give: int = min(ceil(safe_amount), get_parent().gold.gold)
#		get_parent().gold.give_gold(worker.get_parent(), amount_to_give)

	work_applied.emit(self)

	if not needs_work():
		_complete(worker)


# -------------------------
# -------------------------
# Public utility
# -------------------------

func refresh_registration() -> void:
	## Call this if:
	## - the parent’s castle reference changes
	## - you created this node with auto_register=false and now want to register it
	##
	## It ensures we unregister from any previous job board, then re-register on the new one.
	_unregister_from_job_board()
	if enabled:
		_resolve_castle_and_register()


func get_progress_ratio() -> float:
	## Useful for UI or debug (0..1).
	if total_work <= 0.0:
		return 1.0
	return clampf(_work_done / total_work, 0.0, 1.0)


func assign_boss(boss: Node2D) -> void:
	my_boss = boss

	if auto_register and enabled:
		_resolve_castle_and_register()


func set_enabled(new_enabled: bool) -> void:
	if enabled == new_enabled:
		return
	enabled = new_enabled
	if not enabled:
		_unregister_from_job_board()
		_clear_all_reservations()
	elif auto_register:
		_resolve_castle_and_register()


func reset_progress() -> void:
	_work_done = 0.0


func refresh_slots() -> void:
	_collect_slots()


func _collect_slots() -> void:
	_slot_markers.clear()

	var slots_node: Node = get_node_or_null("Slots")
	if slots_node != null:
		_gather_marker_descendants(slots_node, _slot_markers)
	else:
		_gather_marker_descendants(self, _slot_markers)


func _gather_marker_descendants(root: Node, out: Array[Marker2D]) -> void:
	for child in root.get_children():
		if child is Marker2D:
			out.append(child)
		_gather_marker_descendants(child, out)


func _find_free_slot_index() -> int:
	if _slot_markers.is_empty():
		return -1 if _agent_for_slot.has(0) else 0

	for i in range(_slot_markers.size()):
		if not _agent_for_slot.has(i):
			return i
	return -1


func _assign_slot(agent: Node2D, slot_index: int) -> void:
	_slot_for_agent[agent] = slot_index
	_agent_for_slot[slot_index] = agent
	if agent is Node:
		var node_agent: Node = agent
		var exit_callable := _on_agent_exited.bind(agent)
		if not node_agent.tree_exited.is_connected(exit_callable):
			node_agent.tree_exited.connect(exit_callable, CONNECT_ONE_SHOT)


func _get_slot_position(slot_index: int) -> Vector2:
	if _slot_markers.is_empty():
		return global_position
	if slot_index < 0 or slot_index >= _slot_markers.size():
		return global_position
	var marker := _slot_markers[slot_index]
	if not is_instance_valid(marker):
		return global_position
	return marker.global_position


func _cleanup_invalid_agents() -> void:
	for agent in _slot_for_agent.keys():
		if agent == null or not is_instance_valid(agent):
			unreserve(agent)


func _clear_all_reservations() -> void:
	for agent in _slot_for_agent.keys():
		unreserve(agent)


func _on_agent_exited(agent: Node2D) -> void:
	unreserve(agent)


# -------------------------
# Internals: resolve + register
# -------------------------

func _resolve_castle_and_register() -> void:
	if not enabled:
		return
	# First make sure we unregister if board was already registered.
	_unregister_from_job_board()

	## Finds the castle reference from our parent and registers this WorkSite with the castle's JobBoard.
	var _castle: Node = null
	if is_instance_valid(my_boss) and my_boss.has_method("return_castle"):
		_castle = my_boss.return_castle()
	if _castle == null:
		return

	_job_board = _resolve_job_board(_castle)
	if is_instance_valid(_job_board):
		_job_board.register_site(self)


func _get_castle_from_parent() -> Node2D:
	## Attempts to find a castle reference from our parent using conventions.
	## Convention A (preferred): parent implements get_castle() -> Node2D
	## Convention B (fallback): parent has a variable/property called "castle"
	if my_boss == null:
		return null

	# Convention A: method
	if my_boss.has_method("return_castle"):
		var c = my_boss.call("return_castle")
		if c is Node2D:
			return c
	else:
		print_debug("my_boss does not have function return_castle.")

	# Convention B: property
	#var prop = my_boss.get("castle")
	#if prop is Node2D:
	#	return prop

	return null


func _resolve_job_board(castle: Node2D) -> CastleJobBoard:
	## Locates the job board node using conventions.
	## Convention: castle has a child node named "JobBoard"
	if castle == null or not is_instance_valid(castle):
		return null

	return castle.return_job_board(kind)


func _unregister_from_job_board() -> void:
	## Unregisters this WorkSite from the job board, if we are currently registered.
	## This prevents the board from holding stale references after completion or deletion.
	if is_instance_valid(_job_board):
		_job_board.unregister_site(self)

	_job_board = null


# -------------------------
# Internals: completion
# -------------------------

func _complete(worker: MinionTasker) -> void:
	## Called once when work is finished.
	## We unregister from the job board so new workers won't be assigned here,
	## then emit a signal so the parent/building can react (upgrade, spawn loot, etc).
	_unregister_from_job_board()
	work_completed.emit(self, worker)
