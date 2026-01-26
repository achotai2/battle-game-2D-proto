extends CharacterBody2D
class_name AgentBase

## Player number (0 = neutral).
@export var player: int = 0
@export var health: Health = null
@export var interactor: PlayerInteractor = null
@export var movement: AgentMovement = null
@export var pathfinding: MinionPathfinding = null
@export var controls: PlayerControls = null
@export var animation: AgentAnimate = null
@export var attack: Node = null
@export var interactable: Node = null
@export var detection: Area2D = null
@export var tactical: Node = null
@export var tasker: MinionTasker = null
@export var gold: GoldHolder = null
@export var hunger: Hunger = null
@export var castle: Node = null
@export var current_role: StringName

var _min_hunger = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_connect_all_refs()
	apply_role(current_role, player)


func _connect_all_refs() -> void:
	# Connect signals for ANIMATION node.
	_assign_animation_refs()

	# Connect signals for MOVEMENT node.
	_assign_movement_refs()

	# Connect signals for PATHFINDING node.
	_assign_pathfinding_refs()

	# Connect signals for player CONTROLS node.
	_assign_controls_refs()

	# Configure ATTACK node.	
	_assign_weapon_refs()

	# Connect signals for DETECTION node.
	_assign_detection_refs()

	# Connect signals for TACTICAL node.	
	_assign_tactical_refs()

	# Connect signals for TASKER node.	
	_assign_tasker_refs()

	# Connect signals for GOLD node.	
	_assign_gold_refs()

	# Connect signals for HEALTH node.	
	_assign_health_refs()

	# Connect signals for HUNGER node.	
	_assign_hunger_refs()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(movement):
		movement.tick(_delta)

	move_and_slide()


func _assign_weapon_refs() -> void:
	if not is_instance_valid(attack):
		return

	attack.set_player(self)

	if is_instance_valid(movement) and is_instance_valid(attack) and attack.has_method("set_movement"):
		attack.call("set_movement", movement)
	else:
		print_debug("attack node does not contain function set_movement")


func _disconnect_weapon_signals() -> void:
	if not is_instance_valid(attack):
		return


func _assign_animation_refs() -> void:
	if not is_instance_valid(animation):
		return

	animation.set_my_agent(self)


func _assign_movement_refs() -> void:
	if not is_instance_valid(movement):
		return

	if movement.has_method("set_my_agent"):
		movement.call("set_my_agent", self)
	else:
		print_debug("movement does not have function set_my_agent")
		
	if movement.has_method("set_animation"):
		movement.call("set_animation", animation)
	else:
		print_debug("movement does not have function set_animation")

	if movement.has_method("set_pathfinding"):
		movement.call("set_pathfinding", pathfinding)
	else:
		print_debug("movement does not have function set_pathfinding")


func _assign_pathfinding_refs() -> void:
	if not is_instance_valid(pathfinding):
		return

	if pathfinding.has_method("set_castle"):
		pathfinding.call("set_castle", castle)
	else:
		print_debug("pathfinding does not have function set_castle")


func _assign_controls_refs() -> void:
	if not is_instance_valid(controls):
		return
	
	if controls.has_method("set_interactor"):
		controls.call("set_interactor", interactor)
	else:
		print_debug("controls does not have function set_interactor")

	if controls.has_method("set_attackNode"):
		controls.call("set_attackNode", attack)
	else:
		print_debug("controls does not have function set_attackNode")

	if controls.has_method("set_movement"):
		controls.call("set_movement", movement)
	else:
		print_debug("controls does not have function set_movement")


func _assign_detection_refs() -> void:
	if not is_instance_valid(detection):
		return

	if is_instance_valid(detection) and detection.has_method("set_myself"):
		detection.call("set_myself", self)
	else:
		print_debug("detection does not have function set_myself")

	if is_instance_valid(detection) and detection.has_method("set_tactical"):
		detection.call("set_tactical", tactical)
	else:
		print_debug("detection does not have function set_tactical")


func _assign_tactical_refs() -> void:
	if not is_instance_valid(tactical):
		return

	if tactical.has_method("set_agent"):
		tactical.call("set_agent", self)
	else:
		print_debug("No function set_agent in tactical.")

	if tactical.has_method("set_movement"):
		tactical.call("set_movement", movement)
	else:
		print_debug("No function set_movement in tactical.")


func _assign_tasker_refs() -> void:
	if not is_instance_valid(tasker):
		return

	if tasker.has_method("set_agent"):
		tasker.call("set_agent", self)
	else:
		print_debug("No function set_agent in tasker.")

	if tasker.has_method("set_movement"):
		tasker.call("set_movement", movement)
	else:
		print_debug("No function set_movement in tasker.")


func _assign_gold_refs() -> void:
	if not is_instance_valid(gold):
		return
	
	if gold.has_method("set_movement"):
		gold.call("set_movement", movement)
	else:
		print_debug("No function set_movement in gold.")


func _assign_health_refs() -> void:
	if not is_instance_valid(health):
		return

	if not health.damaged.is_connected(_im_damaged):
		health.damaged.connect(_im_damaged)
	if not health.died.is_connected(_im_dead):
		health.died.connect(_im_dead)


func _assign_hunger_refs() -> void:
	if not is_instance_valid(hunger):
		return
		
	if is_instance_valid(movement) and hunger.has_method("set_movement"):	
		hunger.call("set_movement", movement)


func _im_damaged() -> void:
#	if is_instance_valid(animation):
#		animation.show_damage()
	pass


func _im_dead() -> void:
	if current_role == "peasant" or current_role == "player":
		return
	else:
		apply_role("peasant", player)


func _agent_moved(vel: Vector2) -> void:
	# Called by signal from movement when movement occurs.
	self.velocity = vel


##################
# External called.
##################
func apply_role(role: StringName, p: int) -> void:
	# Set the new player number.
	player = p

	# --- remove old role groups ---
	if current_role != null:
		for g: StringName in UnitRoles.get_role_groups(current_role):
			if is_in_group(g):
				remove_from_group(g)

	# --- remove old role-dependent nodes ---
	if is_instance_valid(attack):
		_disconnect_weapon_signals()
		attack.queue_free()
		attack = null

	if is_instance_valid(tactical):
		tactical.queue_free()
		tactical = null

	if is_instance_valid(tasker):
		if tasker.has_method("has_task") and tasker.call("has_task"):
			if tasker.has_method("clear_task"):
				tasker.call("clear_task")
			else:
				print_debug("tasker does not have method clear_task")
		tasker.queue_free()
		tasker = null

	# --- add new weapon (PackedScene) ---
	var weapon_scene: PackedScene = UnitRoles.get_weapon(role)
	if weapon_scene != null:
		attack = weapon_scene.instantiate()
		add_child(attack)

	# --- add new tactical (Script) ---
	var tactical_script: Script = UnitRoles.get_tactical(role)
	if tactical_script != null:
		tactical = tactical_script.new()
		add_child(tactical)

	# --- add new tasker (Script) ---
	var tasker_script: Script = UnitRoles.get_tasker(role)
	if tasker_script != null:
		tasker = tasker_script.new()
		add_child(tasker)

	# --- visuals ---
	var frames: SpriteFrames = UnitRoles.get_frames(role, player)
	if frames != null and is_instance_valid(animation):
		animation.set_sprite_frames(frames)

	# --- add new role groups ---
	for g: StringName in UnitRoles.get_role_groups(role):
		add_to_group(g)

	current_role = role

	# Configure all refs.
	_connect_all_refs()

	# --- tracking refresh ---
	# Cancel transient action states when swapping role
	if is_instance_valid(movement):
		movement.clear_freeze_locks([AgentMovement.LOCK_STUN])
		movement.clear_movement_order(10)

	if is_instance_valid(pathfinding):
		pathfinding.clear_target()

	if is_instance_valid(detection):
		detection.refresh()

	# If you have flags on animation like `attacking`, clear them too
	if is_instance_valid(animation):
		animation.cancel_action_state()


func return_player() -> int:
	return player


func return_position() -> Vector2:
	return self.global_position


func return_velocity() -> Vector2:
	return self.velocity


#func is_idle() -> bool:
#	return true


func return_castle() -> Node:
	return castle


# Called externally to update castle agent is assigned to.
func set_castle(new_castle: Node) -> void:
	castle = new_castle
	if is_instance_valid(pathfinding) and pathfinding.has_method("set_castle"):
		pathfinding.call("set_castle", castle)
	else:
		print_debug("pathfinding does not contain function set_castle, or does not exist.")

	if is_instance_valid(tasker) and tasker.has_method("switch_job_board"):
		tasker.call("switch_job_board", castle)
