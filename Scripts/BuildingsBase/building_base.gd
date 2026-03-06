extends StaticBody3D
class_name BuildingBase

@export var player: int = 0
@export var castle: Castle
@export var building_type: BuildingDefs.BuildingType = BuildingDefs.BuildingType.BARRACKS
@export var visual: Node
@export var shadowVisual: Node
@export var interactable: Interactable
@export var worksite: WorkSite
@export var spawnsite: SpawnSite
@export var gold: GoldWallet
#@export var health: Health
@export var state: BuildingDefs.BuildingState = BuildingDefs.BuildingState.CONSTRUCTING

var _is_ready: bool = false
var _team_memory: TeamMemory = null
var _original_worksite_total_work: float = 0.0


func _ready() -> void:
	_is_ready = true

	_team_memory = ComponentFinder.get_component(self, "TeamMemory")
	if _team_memory:
		_team_memory.current_team = player

	if worksite:
		_original_worksite_total_work = worksite.total_work

	collision_layer = GamePhysics.get_building_layer()

	_connect_signals()
	apply_state(state)


func set_player(p: int) -> void:
	player = p
	if _team_memory:
		_team_memory.current_team = p
	if _is_ready:
		apply_state(state)


func set_castle(c: Castle) -> void:
	castle = c
	if worksite and state == BuildingDefs.BuildingState.CONSTRUCTING:
		worksite.refresh_registration()


func set_state(new_state: BuildingDefs.BuildingState) -> void:
	if state == new_state:
		return
	apply_state(new_state)


func apply_state(new_state: BuildingDefs.BuildingState) -> void:
	state = new_state

	_update_visuals()
	_configure_interactable()
	_configure_worksite()
	_configure_spawnsite()

	_connect_signals()


func return_castle() -> Castle:
	return castle


func return_position() -> Vector3:
	return global_position


func _on_interacted(interactor: AgentBase) -> void:
	if state == BuildingDefs.BuildingState.DESTROYED:
		# If DESTROYED then Player gives building gold (to give to Workers) and sets state to CONSTRUCTING.
		set_state(BuildingDefs.BuildingState.CONSTRUCTING)
	elif state == BuildingDefs.BuildingState.BUILT:
		# If BUILT then Player gives building gold (to give to Workers) and sets state to SPAWNING.
		if spawnsite:
			spawnsite.enqueue_spawn(1)


func _activate_worker_for_spawn(work_amount: float) -> void:
	if worksite and not worksite.enabled:
		worksite.total_work = work_amount
		worksite.reset_progress()
		worksite.set_enabled(true)
		worksite.refresh_registration()


func _on_work_completed(_site: WorkSite, _worker: AgentBase) -> void:
	if state == BuildingDefs.BuildingState.CONSTRUCTING:
		set_state(BuildingDefs.BuildingState.BUILT)
	elif state == BuildingDefs.BuildingState.BUILT:
		if worksite:
			worksite.set_enabled(false)
		if spawnsite and spawnsite.has_method("on_spawn_work_completed"):
			spawnsite.on_spawn_work_completed()


func _on_destroyed() -> void:
	set_state(BuildingDefs.BuildingState.DESTROYED)


func _update_visuals() -> void:
	if not visual:
		return

	var frames := BuildingDefs.get_frames(building_type, state, player)
	if frames == null:
		return

	if visual is AnimatedSprite3D and frames is SpriteFrames:
		var animated := visual as AnimatedSprite3D
		animated.sprite_frames = frames
		if animated.sprite_frames.get_animation_names().size() > 0 and animated.animation == "":
			animated.animation = animated.sprite_frames.get_animation_names()[0]
		animated.play()
	elif visual is Sprite3D and frames is Texture2D:
		(visual as Sprite3D).texture = frames
		if shadowVisual: (shadowVisual as Sprite3D).texture = frames
	elif frames is Texture2D and visual.has_method("set_texture"):
		visual.call("set_texture", frames)
		if shadowVisual: shadowVisual.call("set_texture", frames)


func _configure_interactable() -> void:
	if not interactable:
		return

	var enabled := state != BuildingDefs.BuildingState.CONSTRUCTING
	interactable.set_enabled(enabled)
	
	var _interaction_cost: int = 0
	if state == BuildingDefs.BuildingState.DESTROYED:
		_interaction_cost = worksite.total_work
	elif state == BuildingDefs.BuildingState.BUILT:
		_interaction_cost = spawnsite.work_per_spawn
		
	interactable.update_interaction_state(BuildingDefs.get_interact_mode(building_type, state), _interaction_cost)



func _configure_worksite() -> void:
	if not worksite:
		return
	
	if state == BuildingDefs.BuildingState.CONSTRUCTING:
		if _original_worksite_total_work > 0:
			worksite.total_work = _original_worksite_total_work
		worksite.reset_progress()
		worksite.set_enabled(true)
		worksite.refresh_registration()
	else:
		if spawnsite == null or not spawnsite.has_method("on_spawn_work_completed") or spawnsite.get("_spawn_work_queued") == 0:
			worksite.set_enabled(false)


func _configure_spawnsite() -> void:
	spawnsite.set_enabled(false)


func _connect_signals() -> void:
	if worksite:
		if worksite.work_completed.is_connected(_on_work_completed):
			worksite.work_completed.disconnect(_on_work_completed)
		worksite.work_completed.connect(_on_work_completed)

	if interactable:
		if interactable.interaction_finished.is_connected(_on_interacted):
			interactable.interaction_finished.disconnect(_on_interacted)
		interactable.interaction_finished.connect(_on_interacted)
