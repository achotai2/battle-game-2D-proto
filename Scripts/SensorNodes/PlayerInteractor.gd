extends Node3D
class_name PlayerInteractor

signal interaction_started(target: Interactable)
signal interaction_finished(target: Interactable)
signal interaction_suspended(target: Interactable)

@export var sensor: InteractTracking
@export var prompt_scene: PackedScene
@export var prompt_parent: Node
@export var interact_action: StringName = &"interact"
@export var interaction_timer: Timer

var _current_target: Interactable = null
var _prompt: InteractPrompt = null
var _is_interacting: bool = false


func _ready() -> void:
	pass

func deactivate() -> void:
	if interaction_timer:
		interaction_timer.stop()
	set_process(false)
	set_process_unhandled_input(false)
	_hide_prompt()
	_current_target = null

	if is_instance_valid(sensor):
		if sensor.target_changed.is_connected(_target_changed):
			sensor.target_changed.disconnect(_target_changed)
		if sensor.target_lost.is_connected(_target_lost):
			sensor.target_lost.disconnect(_target_lost)

func activate() -> void:
	set_process(true)
	set_process_unhandled_input(true)
	if is_instance_valid(sensor):
		if not sensor.target_changed.is_connected(_target_changed):
			sensor.target_changed.connect(_target_changed)
		if not sensor.target_lost.is_connected(_target_lost):
			sensor.target_lost.connect(_target_lost)

	prompt_parent = ComponentFinder.get_base(self)

	_setup_prompt()

	# Establish connection to TeamMemory.
	var base = ComponentFinder.get_base(self)
	var team = base.get("team") if base.get("team") else base.get("team_memory")
	if team and not team.team_changed.is_connected(_team_changed):
		team.team_changed.connect(_team_changed)
	_team_changed(team.return_team())


func _team_changed(new_team: int) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action):
		interaction_pressed()
	elif event.is_action_released(interact_action):
		interaction_released()


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


func _set_target(target: Interactable) -> void:
	_current_target = target
	if _current_target == null:
		_hide_prompt()
	else:
		_update_prompt_icon()
		_show_prompt()


func _update_prompt() -> void:
	if _prompt == null:
		return
	if _current_target == null or not is_instance_valid(_current_target) or not _current_target.can_interact(prompt_parent):
		_hide_prompt()
		return

	_update_prompt_icon()
	var anchor_position := _current_target.get_prompt_position()
	var percent_left: float = 1.0
	if not interaction_timer.is_stopped():
		percent_left = interaction_timer.time_left / _current_target.get_interaction_time()
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
	if not _current_target.can_interact(prompt_parent):
		return

	_is_interacting = true

	_current_target.begin_interact(prompt_parent)
	interaction_started.emit(_current_target)

	var duration := _current_target.get_interaction_time()
	if duration <= 0.0:
		_finish_interaction()
	else:
		interaction_timer.start(duration)


func _finish_interaction() -> void:
	if not _is_interacting:
		return
	_is_interacting = false

	var owner_node := _get_interactor_node()

	if _current_target != null and is_instance_valid(_current_target) and owner_node != null:
		if interaction_timer.is_stopped():
			interaction_finished.emit(_current_target)
		else:
			_current_target.suspend_interact(owner_node)
			interaction_timer.stop()
			interaction_suspended.emit(_current_target)


func am_i_interacting() -> bool:
	return _is_interacting


func _target_changed(target: Node3D) -> void:
	if target is Interactable:
		_set_target(target)


func _target_lost() -> void:
	_finish_interaction()
	if _current_target:
		_set_target(null)


func _get_interactor_node() -> AgentBase:
	if prompt_parent is AgentBase:
		return prompt_parent as AgentBase
	return null


func _on_interaction_timer_timeout() -> void:
	_finish_interaction()
