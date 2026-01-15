extends Node2D
class_name PlayerInteractor

signal target_changed(target: Interactable)
signal interaction_started(target: Interactable)
signal interaction_finished(target: Interactable)
signal interaction_suspended(target: Interactable)

@export var sensor: Area2D
@export var prompt_scene: PackedScene
@export var prompt_parent: Node
@export var movement: AgentMovement
@export var interact_action: StringName = &"interact"
@export var freeze_movement: bool = true

var _nearby: Array[Interactable] = []
var _current_target: Interactable = null
var _prompt: InteractPrompt = null
var _interaction_timer: Timer
var _is_interacting: bool = false


func _ready() -> void:
	_interaction_timer = Timer.new()
	_interaction_timer.one_shot = true
	_interaction_timer.timeout.connect(_on_interaction_timeout)
	add_child(_interaction_timer)

	if sensor == null:
		sensor = get_node_or_null("Sensor") as Area2D
	if sensor == null:
		sensor = get_node_or_null("Area2D") as Area2D

	if is_instance_valid(sensor):
		sensor.area_entered.connect(_on_area_entered)
		sensor.area_exited.connect(_on_area_exited)

	_setup_prompt()


func _process(_delta: float) -> void:
	if _is_interacting:
		_update_prompt()
		return	# Don't allow selecting new target if interacting.

	# Select new best target.
	var best := _select_best_target()
	if best != _current_target:
		_set_target(best)
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

	_prompt = prompt_scene.instantiate() as Node2D
	if _prompt == null:
		return

	if prompt_parent != null:
		prompt_parent.add_child(_prompt)
	else:
		add_child(_prompt)
	_prompt.hide()


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
	_prompt.set_base_position(anchor_position, percent_left)
	_show_prompt()


func _show_prompt() -> void:
	if _prompt == null:
		return
	_prompt.show()


func _hide_prompt() -> void:
	if _prompt == null:
		return
	_prompt.hide()


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
		movement.start_interaction()

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


func _on_interaction_timeout() -> void:
	_finish_interaction()


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		var interactable := area as Interactable
		if not _nearby.has(interactable):
			_nearby.append(interactable)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		var interactable := area as Interactable
		_nearby.erase(interactable)

	if _is_interacting:
		return

	if _current_target == area:
		_set_target(_select_best_target())


func _get_interactor_node() -> Node2D:
	if get_parent() is Node2D:
		return get_parent() as Node2D
	return self
