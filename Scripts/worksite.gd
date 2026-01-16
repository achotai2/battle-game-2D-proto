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
## - Move to get_work_position()
## - While in range, call apply_work(amount, worker)
## - When completed, this WorkSite unregisters itself and emits work_completed.


# Emitted once, when total work has been completed.
signal work_completed(site: WorkSite)

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

@export var allow_multiple_workers: bool = true
## If false, this site will attempt to act as "single worker at a time" by tracking _reserved_by.
## Note: the JobBoard also has one_worker_per_site; you can use either or both.

@export var enabled: bool = true
## Whether this WorkSite is currently active and available for workers.


# -------------------------
# Runtime state
# -------------------------

var _work_done: float = 0.0
## Current accumulated work.

var _job_board: CastleJobBoard = null
## Cached job board reference resolved from castle. We keep it so we can unregister cleanly.

var _reserved_by: WorkSiteWorker = null
## Which worker (if any) currently has this site reserved.
## This is optional coordination; your JobBoard may also manage this at a higher level.


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	## Called when the node enters the scene tree.
	## If auto_register is enabled, we locate the castle/job board and register this site as available work.
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
	if my_boss.has_method("return_position"):
		return my_boss.return_position() + work_offset.position
	else:
		return Vector2.ZERO


func apply_work(amount: float, worker: WorkSiteWorker) -> void:
	## Called by a worker to contribute progress toward completion.
	## - amount: how much work this "hit" contributes
	## - worker: the worker doing the work (useful if you want to attribute credit)
	##
	## This function:
	## - ignores work if already completed
	## - clamps negative work to 0
	## - completes the site once total_work reached
	if not enabled or not needs_work():
		return

	var safe_amount: float = maxf(amount, 0.0)
	_work_done = minf(total_work, _work_done + safe_amount)

	if not needs_work():
		_complete()


# -------------------------
# Optional reservation API (used by JobBoard)
# -------------------------

func can_reserve(worker: WorkSiteWorker) -> bool:
	## Optional hook: JobBoard can ask if this site can be reserved by a given worker.
	## Here we enforce:
	## - site must still need work
	## - if allow_multiple_workers is false, only one worker can reserve at a time
	if not needs_work():
		return false

	if allow_multiple_workers:
		return true

	# Single-worker reservation mode:
	return _reserved_by == null or not is_instance_valid(_reserved_by)


func reserve(worker: WorkSiteWorker) -> void:
	## Optional hook: JobBoard calls this when it assigns/reserves the job for a worker.
	## If allow_multiple_workers is true, we don't strictly need this.
	if not allow_multiple_workers:
		_reserved_by = worker


func unreserve(worker: WorkSiteWorker) -> void:
	## Optional hook: JobBoard calls this when releasing the reservation (worker changed jobs, etc.)
	## Clears our _reserved_by only if it matches the releasing worker.
	if _reserved_by == worker:
		_reserved_by = null


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
		_reserved_by = null
	elif auto_register:
		_resolve_castle_and_register()


func reset_progress() -> void:
	_work_done = 0.0


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

	# Convention B: property
	#var prop = my_boss.get("castle")
	#if prop is Node2D:
	#	return prop

	return null


func _resolve_job_board(castle: Node2D) -> CastleJobBoard:
	## Locates the job board node using conventions.
	## Convention A: castle has a child node named "JobBoard"
	## Convention B: castle itself *is* the job board (implements register_site)
	if castle == null or not is_instance_valid(castle):
		return null

	if castle.has_method("return_job_board"):
		return castle.call("return_job_board")

	return null


func _unregister_from_job_board() -> void:
	## Unregisters this WorkSite from the job board, if we are currently registered.
	## This prevents the board from holding stale references after completion or deletion.
	if is_instance_valid(_job_board):
		_job_board.unregister_site(self)

	_job_board = null


# -------------------------
# Internals: completion
# -------------------------

func _complete() -> void:
	## Called once when work is finished.
	## We unregister from the job board so new workers won't be assigned here,
	## then emit a signal so the parent/building can react (upgrade, spawn loot, etc).
	_unregister_from_job_board()
	work_completed.emit(self)
