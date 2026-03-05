extends Area3D
class_name Interactable

signal interaction_started(interactor: AgentBase)
signal interaction_finished(interactor: AgentBase)
signal interaction_suspended(interactor: AgentBase)

@export var interaction_time: float = 1.0
@export var one_shot: bool = false
@export var requires_same_team: bool = false
@export var allows_neutral: bool = true
@export var icon_type: BuildingDefs.IconType = BuildingDefs.IconType.CONSTRUCT
@export var prompt_anchor: Node3D

var _disabled: bool = false
var _active_interactor: AgentBase = null
var _interaction_cost: int = 0
var _team_memory: TeamMemory = null

func _ready() -> void:
	call_deferred("_late_ready")

func _late_ready() -> void:
	_team_memory = ComponentFinder.get_component(self, "TeamMemory")
	if _team_memory and not _team_memory.team_changed.is_connected(_on_team_changed):
		_team_memory.team_changed.connect(_on_team_changed)
		_on_team_changed(_team_memory.return_team())
	else:
		_on_team_changed(0)


func _on_team_changed(new_team: int) -> void:
	match new_team:
		0:
			collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_INTERACTABLE_NEUTRAL)
		1:
			collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_INTERACTABLE_PLAYER_1)
		2:
			collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_INTERACTABLE_PLAYER_2)
		_:
			collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_INTERACTABLE_NEUTRAL)


func can_interact(interactor: AgentBase) -> bool:
	if _disabled:
		return false
	if _active_interactor != null and _active_interactor != interactor:
		return false

	return true


func begin_interact(interactor: AgentBase) -> void:
	if _active_interactor != null:
		return
	if not can_interact(interactor):
		return

	_active_interactor = interactor
	interaction_started.emit(interactor)


func finish_interact(interactor: AgentBase) -> void:
	if _active_interactor != interactor:
		return

	# Order interacting Player to give gold equal to interaction cost.
	if is_instance_valid(interactor.gold) and interactor.gold.gold >= _interaction_cost:
		interactor.gold.give_gold(get_parent(), _interaction_cost)

		_active_interactor = null
		if one_shot:
			_disable_interaction()

		interaction_finished.emit(interactor)


func suspend_interact(interactor: AgentBase) -> void:
	if _active_interactor != interactor:
		return

	_active_interactor = null
	interaction_suspended.emit(interactor)


func get_interaction_time() -> float:
	return interaction_time


func get_prompt_position() -> Vector3:
	var anchor := prompt_anchor
	if anchor == null:
		anchor = get_node_or_null("PromptAnchor") as Node3D
	if is_instance_valid(anchor):
		return anchor.global_position
	if get_parent() is AgentBase:
		return (get_parent() as AgentBase).global_position
	return global_position


func _get_team_id(entity: Node) -> int:
	if entity is AgentBase:
		return (entity as AgentBase).player
	return 0


func update_interaction_state(new_icon: BuildingDefs.IconType, new_cost: int) -> void:
	icon_type = new_icon
	_interaction_cost = new_cost


func _disable_interaction() -> void:
	_disabled = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func set_enabled(enabled: bool) -> void:
	_disabled = not enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)


func get_prompt_icon_type() -> BuildingDefs.IconType:
	return icon_type


func get_prompt_cost() -> int:
	return _interaction_cost
