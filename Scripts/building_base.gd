extends StaticBody2D
class_name BuildingBase

enum BuildingState { DESTROYED, CONSTRUCTING, BUILT }

@export var player: int = 0
@export var castle: Node2D
@export var building_type: StringName = &""
@export var visual: Node
@export var interactable: Interactable
@export var worksite: WorkSite
@export var spawnsite: WorkSite
@export var health: Health
@export var state: BuildingState = BuildingState.CONSTRUCTING

var _is_ready: bool = false


func _ready() -> void:
	_is_ready = true

	if is_instance_valid(worksite) and worksite.has_method("assign_boss"):
		worksite.call("assign_boss", self)
	else:
		print_debug("worksite does not have function assign_boss")
	if is_instance_valid(spawnsite) and spawnsite.has_method("assign_boss"):
		spawnsite.call("assign_boss", self)
	else:
		print_debug("spawnsite does not have function assign_boss")

	_connect_signals()
	apply_state(state)


func set_player(p: int) -> void:
	player = p
	if _is_ready:
		apply_state(state)


func set_castle(c: Node2D) -> void:
	castle = c
	if is_instance_valid(worksite) and state == BuildingState.CONSTRUCTING:
		worksite.refresh_registration()


func set_state(new_state: BuildingState) -> void:
	if state == new_state:
		return
	apply_state(new_state)


func apply_state(new_state: BuildingState) -> void:
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
	if state == BuildingState.DESTROYED:
		set_state(BuildingState.CONSTRUCTING)
	elif state == BuildingState.BUILT:
		_activate_spawnsite()


func _on_work_completed(_site: WorkSite, _worker: WorkSiteWorker) -> void:
	set_state(BuildingState.BUILT)


func _on_destroyed() -> void:
	set_state(BuildingState.DESTROYED)


func _update_visuals() -> void:
	if not is_instance_valid(visual):
		return

	var frames := BuildingDefs.get_frames(building_type, state, player)
	if frames == null:
		return

	if visual is AnimatedSprite2D and frames is SpriteFrames:
		var animated := visual as AnimatedSprite2D
		animated.sprite_frames = frames
		if animated.sprite_frames.get_animation_names().size() > 0 and animated.animation == "":
			animated.animation = animated.sprite_frames.get_animation_names()[0]
		animated.play()
	elif visual is Sprite2D and frames is Texture2D:
		(visual as Sprite2D).texture = frames
	elif frames is Texture2D and visual.has_method("set_texture"):
		visual.call("set_texture", frames)


func _configure_interactable() -> void:
	if not is_instance_valid(interactable):
		return

	var enabled := state != BuildingState.CONSTRUCTING
	interactable.set_enabled(enabled)
	interactable.icon_type = BuildingDefs.get_interact_mode(building_type, state)


func _configure_worksite() -> void:
	if state == BuildingState.CONSTRUCTING and is_instance_valid(worksite):
		spawnsite.set_enabled(false)
		worksite.reset_progress()
		worksite.set_enabled(true)
		worksite.refresh_registration()
	elif state == BuildingState.BUILT and is_instance_valid(spawnsite):
		worksite.set_enabled(false)
		spawnsite.set_enabled(false)
	else:
		if is_instance_valid(worksite): worksite.set_enabled(false)
		if is_instance_valid(spawnsite): spawnsite.set_enabled(false)


func _activate_spawnsite() -> void:
	if not is_instance_valid(spawnsite):
		return
	if spawnsite.has_method("enqueue_spawn"):
		spawnsite.call("enqueue_spawn", 1)
		return
	else:
		print_debug("spawnsite does not have function enqueue_spawn")
	if spawnsite.enabled:
		return
	spawnsite.reset_progress()
	spawnsite.set_enabled(true)
	spawnsite.refresh_registration()


func _connect_signals() -> void:
	if is_instance_valid(worksite):
		if worksite.work_completed.is_connected(_on_work_completed):
			worksite.work_completed.disconnect(_on_work_completed)
		worksite.work_completed.connect(_on_work_completed)

	if is_instance_valid(interactable):
		if interactable.interaction_finished.is_connected(_on_interacted):
			interactable.interaction_finished.disconnect(_on_interacted)
		interactable.interaction_finished.connect(_on_interacted)

	if is_instance_valid(health):
		if health.died.is_connected(_on_destroyed):
			health.died.disconnect(_on_destroyed)
		health.died.connect(_on_destroyed)
