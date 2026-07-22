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

@export var interaction_cost: int = 0
## The cost required for the player to instigate the work.

@export var enabled: bool = true
## Whether this WorkSite is currently active and available for workers.

@export var auto_work_interval: float = 1.0
@export var auto_work_amount: float = 1.0

# -------------------------
# Runtime state
# -------------------------

var instigator: Node2D = null
## The player who instigated this work (if applicable).

var _work_done: float = 0.0
## Current accumulated work.

var _work_timer: Timer


# -------------------------
# Lifecycle
# -------------------------

func _ready() -> void:
	_work_timer = Timer.new()
	_work_timer.wait_time = auto_work_interval
	_work_timer.timeout.connect(_on_auto_work_tick)
	add_child(_work_timer)
	if enabled:
		_work_timer.start()




# -------------------------
# Public API (used by workers / job board)
# -------------------------

func needs_work() -> bool:
	## Returns whether this work site still requires work.
	## The JobBoard uses this to decide if the job is still valid.
	if not enabled:
		return false
		
	return _work_done < total_work









func apply_work(amount: float, worker: Node = null) -> void:
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


func get_progress_ratio() -> float:
	## Useful for UI or debug (0..1).
	if total_work <= 0.0:
		return 1.0
	return clampf(_work_done / total_work, 0.0, 1.0)


func assign_boss(boss: Node2D) -> void:
	my_boss = boss


func set_enabled(new_enabled: bool) -> void:
	if enabled == new_enabled:
		return
	enabled = new_enabled
	if not enabled:
		_work_timer.stop()
	else:
		_work_timer.start()


func reset_progress() -> void:
	_work_done = 0.0















func _complete(worker: Node) -> void:
	## Called once when work is finished.
	## We unregister from the job board so new workers won't be assigned here,
	## then emit a signal so the parent/building can react (upgrade, spawn loot, etc).
	if interaction_cost < 0 and is_instance_valid(instigator) and is_instance_valid(instigator.gold):
		instigator.gold.receive_gold(-interaction_cost)

	work_completed.emit(self, worker)

func _on_auto_work_tick() -> void:
	if needs_work():
		apply_work(auto_work_amount, null)
