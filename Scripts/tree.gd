extends StaticBody2D
class_name TreeBase

enum TreeState { NORMAL, MARKED, CUT }

@export var castle: Node2D
@export var building_type: StringName = &""
@export var visual: Node
@export var interactable: Interactable
@export var worksite: WorkSite
@export var resourcesite: ResourceSite
@export var regrow_timer: Timer
@export var spawn_timer: Timer
@export var state: TreeState = TreeState.NORMAL
@export var regrow: bool = false

var _is_ready: bool = false


func _ready() -> void:
	_is_ready = true

	if is_instance_valid(worksite) and worksite.has_method("assign_boss"):
		worksite.call("assign_boss", self)
	else:
		print_debug("worksite does not have function assign_boss")

	_connect_signals()
	apply_state(state)

	if is_instance_valid(spawn_timer):
		# Stagger start
		spawn_timer.stop()
		var stagger_time = randf_range(0.0, 10.0)
		await get_tree().create_timer(stagger_time).timeout
		spawn_timer.start()


func set_castle(c: Node2D) -> void:
	castle = c
	if is_instance_valid(worksite) and state == TreeState.MARKED:
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
	if state == TreeState.NORMAL:
		set_state(TreeState.MARKED)


func _on_work_completed(_site: WorkSite) -> void:
	set_state(TreeState.CUT)

	if is_instance_valid(resourcesite) and resourcesite.has_method("spawn"):
		resourcesite.call("spawn")
	else:
		print_debug("resourcesite does not exist or doesn't have function spawn.")

	_disable_collision()

	if regrow:
		regrow_timer.start()


func _on_work_applied(_site: WorkSite) -> void:
	if not is_instance_valid(visual):
		return

	visual.play("chop")


func _update_visuals() -> void:
	if not is_instance_valid(visual):
		return

	match state:
		TreeState.NORMAL:
			visual.play("idle")
		TreeState.MARKED:
			visual.play("idle_marked")
		TreeState.CUT:
			visual.play("chopped")


func _configure_interactable() -> void:
	if not is_instance_valid(interactable):
		return

	var enabled := state == TreeState.NORMAL
	interactable.set_enabled(enabled)
	interactable.icon_type = &"cut"


func _configure_worksite() -> void:
	if state == TreeState.MARKED and is_instance_valid(worksite):
		if is_instance_valid(worksite):
			worksite.reset_progress()
			worksite.set_enabled(true)
			worksite.refresh_registration()
	else:
		if is_instance_valid(worksite): worksite.set_enabled(false)


func _connect_signals() -> void:
	if is_instance_valid(worksite):
		if worksite.work_completed.is_connected(_on_work_completed):
			worksite.work_completed.disconnect(_on_work_completed)
		worksite.work_completed.connect(_on_work_completed)

		if worksite.work_applied.is_connected(_on_work_applied):
			worksite.work_applied.disconnect(_on_work_applied)
		worksite.work_applied.connect(_on_work_applied)

	if is_instance_valid(interactable):
		if interactable.interaction_finished.is_connected(_on_interacted):
			interactable.interaction_finished.disconnect(_on_interacted)
		interactable.interaction_finished.connect(_on_interacted)


func _on_regrow_timer_timeout() -> void:
	set_state(TreeState.NORMAL)
	_enable_collision()


func _disable_collision() -> void:
	$CollisionShape2D.disabled = true
	$NavigationObstacle2D.avoidance_enabled = false


func _enable_collision() -> void:
	$CollisionShape2D.disabled = false
	$NavigationObstacle2D.avoidance_enabled = false


func _on_spawn_timer_timeout() -> void:
	if randf() < 0.25: # 25% probability
		var sheep_scene = ResourceSiteDefs.get_scene(ResourceSiteDefs.ResourceType.SHEEP)
		if sheep_scene:
			var sheep = sheep_scene.instantiate()
			sheep.global_position = global_position
			get_parent().add_child(sheep)
