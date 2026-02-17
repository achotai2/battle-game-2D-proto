extends Node3D
class_name PlayerInteractor

signal target_changed(target: Interactable)
signal interaction_started(target: Interactable)
signal interaction_finished(target: Interactable)
signal interaction_suspended(target: Interactable)

@export var sensor: Area3D
@export var prompt_scene: PackedScene
@export var prompt_parent: Node
@export var movement: AgentMovement
@export var interact_action: StringName = &"interact"
@export var freeze_movement: bool = true
@export var interact_priority: int = 10

var _nearby: Array[Interactable] = []
var _current_target: Interactable = null
var _prompt: InteractPrompt = null
var _interaction_timer: Timer
var _target_refresh_timer: Timer
var _is_interacting: bool = false
var _target_refresh_interval: float = 0.1
var _initial_sync_done: bool = false


func _ready() -> void:
	_interaction_timer = Timer.new()
	_interaction_timer.one_shot = true
	_interaction_timer.timeout.connect(_on_interaction_timeout)
	add_child(_interaction_timer)

	_target_refresh_timer = Timer.new()
	_target_refresh_timer.wait_time = _target_refresh_interval
	_target_refresh_timer.autostart = true
	_target_refresh_timer.timeout.connect(_refresh_target)
	add_child(_target_refresh_timer)

	if sensor == null:
		sensor = get_node_or_null("Sensor") as Area3D
	if sensor == null:
		sensor = get_node_or_null("Area3D") as Area3D

	if is_instance_valid(sensor):
		sensor.area_entered.connect(_on_area_entered)
		sensor.area_exited.connect(_on_area_exited)

	_setup_prompt()


func _process(_delta: float) -> void:
	_update_prompt()


func interaction_pressed() -> void:
# Called by player controls node.
	_try_start_interaction()


func interaction_released() -> void:
# Called by player controls node.
	_finish_interaction()


func _setup_prompt() -> void:
	if prompt_scene == null:
		return

	_prompt = prompt_scene.instantiate() as InteractPrompt
	if _prompt == null:
		return

	if prompt_parent != null:
		prompt_parent.add_child(_prompt)
	else:
		add_child(_prompt)
	_prompt.hide_prompt()


func _select_best_target() -> Interactable:
	if _nearby.is_empty():
		return null

	var owner_node := _get_interactor_node()
	if owner_node == null:
		return null

	var best: Interactable = null
	var best_priority := -999999
	var best_dist := INF

	for candidate in _nearby:
		if not is_instance_valid(candidate):
			continue
		if not candidate.can_interact(owner_node):
			continue
		var priority := candidate.priority
		var dist := owner_node.global_position.distance_squared_to(candidate.global_position)
		if priority > best_priority or (priority == best_priority and dist < best_dist):
			best = candidate
			best_priority = priority
			best_dist = dist

	return best


func _set_target(target: Interactable) -> void:
	_current_target = target
	if _current_target == null:
		_hide_prompt()
	else:
		_update_prompt_icon()
		_show_prompt()

	target_changed.emit(_current_target)


func _update_prompt() -> void:
	if _prompt == null:
		return
	if _current_target == null or not is_instance_valid(_current_target):
		_hide_prompt()
		return

	var anchor_position := _current_target.get_prompt_position()
	var percent_left: float = 1.0
	if not _interaction_timer.is_stopped():
		percent_left = _interaction_timer.time_left / _current_target.get_interaction_time()
	_prompt.set_world_target(anchor_position, percent_left)
	_show_prompt()


func _show_prompt() -> void:
	if _prompt == null:
		return
	_prompt.show_prompt()


func _update_prompt_icon() -> void:
	if _current_target == null:
		return

	if prompt_scene == null:
		return

	_prompt.update_icon(_current_target.get_prompt_icon_type())
	_prompt.update_cost(_current_target.get_prompt_cost())


func _hide_prompt() -> void:
	if _prompt == null:
		return
	_prompt.hide_prompt()


func _try_start_interaction() -> void:
	if _is_interacting:
		return
	if _current_target == null or not is_instance_valid(_current_target):
		return

	var owner_node := _get_interactor_node()
	if owner_node == null:
		return
	if not _current_target.can_interact(owner_node):
		return

	_is_interacting = true
	if freeze_movement and is_instance_valid(movement):
		movement.command_start_interaction(interact_priority)

	_current_target.begin_interact(owner_node)
	interaction_started.emit(_current_target)

	var duration := _current_target.get_interaction_time()
	if duration <= 0.0:
		_finish_interaction()
	else:
		_interaction_timer.start(duration)


func _finish_interaction() -> void:
	if not _is_interacting:
		return
	_is_interacting = false

	var owner_node := _get_interactor_node()

	if _current_target != null and is_instance_valid(_current_target) and owner_node != null:
		if _interaction_timer.is_stopped():
			_current_target.finish_interact(owner_node)
			interaction_finished.emit(_current_target)
		else:
			_current_target.suspend_interact(owner_node)
			_interaction_timer.stop()
			interaction_suspended.emit(_current_target)

	if is_instance_valid(movement):
		movement.clear_movement_order(interact_priority)

	_refresh_target()


func _on_interaction_timeout() -> void:
	_finish_interaction()


func am_i_interacting() -> bool:
	return _is_interacting


func _refresh_target() -> void:
	if _is_interacting:
		return

	if not _initial_sync_done:
		_sync_nearby_from_sensor()
		_initial_sync_done = true

	# Select new best target.
	var best := _select_best_target()
	if best != _current_target:
		_set_target(best)


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable:
		var interactable := area as Interactable
		if not _nearby.has(interactable):
			_nearby.append(interactable)


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		var interactable := area as Interactable
		_nearby.erase(interactable)

	if _is_interacting:
		return

	if _current_target == area:
		_set_target(_select_best_target())


func _sync_nearby_from_sensor() -> void:
	if not is_instance_valid(sensor):
		return

	var overlapping := sensor.get_overlapping_areas()
	var updated: Array[Interactable] = []
	for area in overlapping:
		if area is Interactable:
			updated.append(area)
	_nearby = updated


func _get_interactor_node() -> CharacterBody3D:
	if get_parent() is CharacterBody3D:
		return get_parent() as CharacterBody3D
	return null
