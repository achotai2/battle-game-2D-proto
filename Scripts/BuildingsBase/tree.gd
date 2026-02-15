extends StaticBody2D
class_name TreeBase

enum TreeState { NORMAL, MARKED, CUT }

@export var castle: Node2D
@export var building_type: StringName = &""
@export var visual: Node
@export var shadowVisual: Node
@export var interactable: Interactable
@export var worksite: WorkSite
@export var gold: GoldHolder
@export var resourcesite: ResourceSite
@export var regrow_timer: Timer
@export var spawn_timer: Timer
@export var spawn_probability: float = 0.25
@export var state: TreeState = TreeState.NORMAL
@export var regrow: bool = false

var _is_ready: bool = false


func _ready() -> void:
	_is_ready = true

	if worksite and worksite.has_method("assign_boss"):
		worksite.call("assign_boss", self)
	else:
		print_debug("worksite does not have function assign_boss")

	_connect_signals()
	apply_state(state)

	if spawn_timer:
		# Stagger start
		spawn_timer.stop()
		var stagger_time = randf_range(0.0, 5.0)
		spawn_timer.start(stagger_time)


func set_castle(c: Node2D) -> void:
	castle = c
	if worksite and state == TreeState.MARKED:
		worksite.refresh_registration()


func set_state(new_state: TreeState) -> void:
	if state == new_state:
		return
	apply_state(new_state)


func apply_state(new_state: TreeState) -> void:
	state = new_state

	_update_visuals()
	_configure_interactable()
	_configure_worksite()

	_connect_signals()


func return_castle() -> Node2D:
	return castle


func return_position() -> Vector2:
	return global_position


func _on_interacted(interactor: Node2D) -> void:
	if state == TreeState.NORMAL and is_instance_valid(interactor.gold) and interactor.gold.gold >= worksite.total_work:
		interactor.gold.give_gold(self, worksite.total_work)
		set_state(TreeState.MARKED)


func _on_work_completed(_site: WorkSite, _worker: WorkSiteWorker) -> void:
	set_state(TreeState.CUT)

	spawn_timer.stop()

	_disable_collision()

	if regrow:
		regrow_timer.start()


func _on_work_applied(_site: WorkSite) -> void:
	if not visual:
		return

	visual.play("chop")
	if shadowVisual: shadowVisual.play("chop")


func _update_visuals() -> void:
	if not visual:
		return

	match state:
		TreeState.NORMAL:
			visual.play("idle")
			if shadowVisual: shadowVisual.play("idle")
		TreeState.MARKED:
			visual.play("idle_marked")
			if shadowVisual: shadowVisual.play("idle_marked")
		TreeState.CUT:
			visual.play("chopped")
			if shadowVisual: shadowVisual.play("chopped")


func _configure_interactable() -> void:
	if not interactable:
		return

	var enabled := state == TreeState.NORMAL
	interactable.set_enabled(enabled)
	interactable.icon_type = BuildingDefs.IconType.CUT


func _configure_worksite() -> void:
	if state == TreeState.MARKED and worksite:
		if worksite:
			worksite.reset_progress()
			worksite.set_enabled(true)
			worksite.refresh_registration()
	else:
		if worksite: worksite.set_enabled(false)


func _connect_signals() -> void:
	if worksite:
		if worksite.work_completed.is_connected(_on_work_completed):
			worksite.work_completed.disconnect(_on_work_completed)
		worksite.work_completed.connect(_on_work_completed)

		if worksite.work_applied.is_connected(_on_work_applied):
			worksite.work_applied.disconnect(_on_work_applied)
		worksite.work_applied.connect(_on_work_applied)

	if interactable:
		if interactable.interaction_finished.is_connected(_on_interacted):
			interactable.interaction_finished.disconnect(_on_interacted)
		interactable.interaction_finished.connect(_on_interacted)


func _on_regrow_timer_timeout() -> void:
	set_state(TreeState.NORMAL)
	_enable_collision()


func _disable_collision() -> void:
	pass
#	$CollisionShape2D.disabled = true


func _enable_collision() -> void:
	pass
#	$CollisionShape2D.disabled = true


func _on_spawn_timer_timeout() -> void:
	if resourcesite and resourcesite.has_method("spawn"):
		if randf() < spawn_probability: # 25% probability
			resourcesite.call("spawn")
	else:
		print_debug("resourcesite does not exist or doesn't have function spawn.")
