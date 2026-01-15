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
@export var castle: Node = null
@export var tactical: Node = null
@export var current_role: StringName


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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

	# Connect signals for HEALTH node.	
	_assign_health_refs()
	

func _physics_process(_delta: float) -> void:
	if is_instance_valid(pathfinding) and is_instance_valid(movement):
		# Update pathfinding information.
		pathfinding.tick(global_position, movement.return_speed(), _delta)

	move_and_slide()


func _assign_weapon_refs() -> void:
	if not is_instance_valid(attack):
		return

	attack.set_player(self)

	if is_instance_valid(animation) and _node_has_property(attack, &"animation"):
		attack.set("animation", animation)

		if attack.has_method("attack_animation_finished") and not animation.attackAnimationFinished.is_connected(attack.attack_animation_finished):
			animation.attackAnimationFinished.connect(attack.attack_animation_finished)

	if is_instance_valid(movement) and _node_has_property(attack, &"movement"):
		attack.set("movement", movement)


func _disconnect_weapon_signals() -> void:
	if not is_instance_valid(attack):
		return

	if attack.has_method("attack_animation_finished") and animation.attackAnimationFinished.is_connected(attack.attack_animation_finished):
		animation.attackAnimationFinished.disconnect(attack.attack_animation_finished)


func _assign_animation_refs() -> void:
	if not is_instance_valid(animation):
		return

	animation.set_my_agent(self)

	if _node_has_property(animation, &"tactical"):
		animation.set("tactical", tactical)


func _assign_movement_refs() -> void:
	if not is_instance_valid(movement):
		return

	if movement.has_method("set_my_agent"):
		movement.call("set_my_agent", self)
		
	elif _node_has_property(movement, &"agent"):
		movement.set("agent", self)

	if _node_has_property(movement, &"animation"):
		movement.set("animation", animation)


func _assign_pathfinding_refs() -> void:
	if not is_instance_valid(pathfinding):
		return

	if _node_has_property(pathfinding, &"movement"):
		pathfinding.set("movement", movement)


func _assign_controls_refs() -> void:
	if not is_instance_valid(controls):
		return

	if _node_has_property(controls, &"interactor"):
		controls.set("interactor", interactor)

	if _node_has_property(controls, &"attackNode"):
		controls.set("attackNode", attack)

	if _node_has_property(controls, &"movement"):
		controls.set("movement", movement)


func _assign_detection_refs() -> void:
	if not is_instance_valid(detection):
		return

	detection.set_myself(self)

	if _node_has_property(detection, &"tactical"):
		detection.set("tactical", tactical)


func _assign_tactical_refs() -> void:
	if not is_instance_valid(tactical):
		return

	if tactical.has_method("set_agent"):
		tactical.call("set_agent", self)

	if _node_has_property(tactical, &"movement"):
		tactical.set("movement", movement)

	if _node_has_property(tactical, &"pathfinding"):
		tactical.set("pathfinding", pathfinding)

	if _node_has_property(tactical, &"animation"):
		tactical.set("animation", animation)


func _assign_health_refs() -> void:
	if not is_instance_valid(health):
		return

	if not health.damaged.is_connected(_im_damaged):
		health.damaged.connect(_im_damaged)
	if not health.died.is_connected(_im_dead):
		health.died.connect(_im_dead)


func _clear_tactical_refs() -> void:
	if is_instance_valid(animation) and _node_has_property(animation, &"tactical"):
		animation.set("tactical", null)

	if is_instance_valid(detection) and _node_has_property(detection, &"tactical"):
		detection.set("tactical", null)


func _node_has_property(node: Object, property_name: StringName) -> bool:
	for prop in node.get_property_list():
		if prop.name == property_name:
			return true
	return false


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
		_clear_tactical_refs()
		tactical.queue_free()
		tactical = null

	# --- add new weapon (PackedScene) ---
	var weapon_scene: PackedScene = UnitRoles.get_weapon(role)
	if weapon_scene != null:
		attack = weapon_scene.instantiate()
		add_child(attack)

		# Configure attack signals
		_assign_weapon_refs()

	# --- add new tactical (Script) ---
	var tactical_script: Script = UnitRoles.get_tactical(role)
	if tactical_script != null:
		tactical = tactical_script.new()
		add_child(tactical)

		# Configure tactical refs.
		_assign_tactical_refs()
		_assign_animation_refs()
		_assign_detection_refs()
		_assign_controls_refs()

	# --- visuals ---
	var frames: SpriteFrames = UnitRoles.get_frames(role, player)
	if frames != null and is_instance_valid(animation):
		animation.set_sprite_frames(frames)

	# --- add new role groups ---
	for g: StringName in UnitRoles.get_role_groups(role):
		add_to_group(g)

	current_role = role

	# --- tracking refresh ---
	# Cancel transient action states when swapping role
	if is_instance_valid(movement):
		movement.un_freeze()

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

	if is_instance_valid(tactical) and tactical.has_method("switch_job_board"):
		tactical.call("switch_job_board", castle)


#func spawned_this_resource(spawned: Node) -> void:
#	pass


#func return_health() -> int:
#	return 100 
	#if is_instance_valid(health):
		#return health.return_health()
	#else:
		#return 0


#func delete_me() -> void:
#	if is_instance_valid(task):
#		task.remove_me(self)
#	self.queue_free()


#func return_to_castle() -> void:
#	if is_instance_valid(castle):
#		castle.give_me_task(self)


# Called by resource _body_entered when picked up by this agent.
#func carry_me(thing: Node) -> void:
#	thing.reparent(self)
#	carrying = thing
#	thing.global_position = self.global_position


#func set_player(newPlayer: int, newCastle: Node, goldAmount: int) -> void:
#	#playerUpdate.emit(newPlayer)
#	player = newPlayer
#	castle = newCastle
#	if is_instance_valid(gold):
#		gold.pickup_gold(goldAmount)


# PROBABLY BEST TO MOVE INTO SEPARATE BASES
#func task_command(taskType: String, taskPlayer: int) -> void:
#	# Called by tasks
#	if self.is_in_group("Goblins") and taskType == "Gold":
#		if is_instance_valid(gold):
#			gold.pickup_gold(-1)
#		set_player(taskPlayer, get_parent().get_closest_castle(taskPlayer, return_position()), 0)
#
#	elif self.is_in_group("Goblins") and taskType == "Spawn":
#		delete_me()


# Called by spawns when a unit is spawned from this unit.
#func return_my_gold() -> int:
#	if is_instance_valid(gold):
#		return gold.return_gold()
#	else:
#		return 0
