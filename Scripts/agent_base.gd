extends CharacterBody2D
class_name AgentBase

## Player number (0 = neutral).
@export var player: int = 0
@export var health: Health = null
@export var interaction: Node = null
@export var movement: AgentMovement = null
@export var pathfinding: MinionPathfinding = null
@export var controls: PlayerControls = null
@export var animation: AgentAnimate = null
@export var attack: Node = null
@export var interact: Node = null
@export var gold: Node = null
@export var base: Node = null
@export var task: MinionTask = null
@export var detection: Area2D = null
@export var castle: Node = null
@export var carrying: Node = null
@export var tactical: Node = null
@export var current_role: StringName


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#if is_instance_valid(interaction):
	#	interaction.noInteractTarget.connect(_no_interact_target)
	#	interaction.set_player(self, player)

	#if is_instance_valid(interact):
	#	interact.update_time_step(false, false)
	#	interact.interactionFinished.connect(_interaction_finished)

	#if is_instance_valid(task):
	#	task.returnedCarry.connect(_returned_carry)

	# Connect signals for ANIMATION node.
	if is_instance_valid(animation):
		animation.set_my_agent(self)

	# Connect signals for MOVEMENT node.
	if is_instance_valid(movement):
		movement.connect("iMoved", Callable(self, "_agent_moved"))
		
		if is_instance_valid(animation):
			movement.connect("iMoved", Callable(animation, "agent_moved"))

	# Connect signals for PATHFINDING node.
	if is_instance_valid(pathfinding) and is_instance_valid(movement):
		pathfinding.connect("desired_velocity", Callable(movement, "on_pf_desired_velocity"))

	# Connect signals for player CONTROLS node.
	if is_instance_valid(controls):
		if is_instance_valid(interaction):
			controls.connect("interact_engaged", Callable(interaction, "interaction_engaged"))
			controls.connect("interact_released", Callable(interaction, "interaction_released"))

		if is_instance_valid(tactical):
			if tactical.has_method("player_controls_activated"):
				controls.connect("interact_engaged", Callable(tactical, "player_controls_activated"))
			if tactical.has_method("player_movement_activated"):
				controls.connect("move_agent", Callable(tactical, "player_movement_activated"))
			if tactical.has_method("player_controls_deactivated"):
				controls.connect("interact_released", Callable(tactical, "player_controls_deactivated"))

		if is_instance_valid(movement):
			controls.connect("move_agent", Callable(movement, "player_controlled_movement"))

	# Configure ATTACK node.	
	_attack_signals()

	# Connect signals for DETECTION node.
	if is_instance_valid(detection):
		detection.set_myself(self)
	_detection_signals()

	# Connect signals for TACTICAL node.	
	_tactical_signals()

	# Connect signals for HEALTH node.	
	if is_instance_valid(health):
		health.damaged.connect(_im_damaged)
		health.died.connect(_im_dead)


func _physics_process(_delta: float) -> void:
# THIS CHANGE SHOULDNT HAPPEN EVERY TIME STEP, INSTEAD TRIGGER IT WHEN THESE STATES CHANGE.
	#if !is_instance_valid(task) and is_instance_valid(detection) and !detection.has_target() and is_instance_valid(movement):
		## If there's no task or target then unit can meander, assuming it can_meander.
		#if movement.make_meander():
			#pathfinding.set_meander(true)
		#else:
			#pathfinding.set_meander(false)
	#else:
		#movement.give_task()
		#pathfinding.set_meander(false)

	if is_instance_valid(pathfinding) and is_instance_valid(movement):
		# Update pathfinding information.
		pathfinding.tick(global_position, movement.return_speed(), _delta)

	move_and_slide()


func _attack_signals() -> void:
	# Connect signals for ATTACK node.
	# These get their own function because they are called in apply_role also.
# COULD THINK ABOUT COMBINING TACTICAL AND ATTACK, AS THEY SHOULD ALWAYS BE CONNECTED PROBABLY.
	if is_instance_valid(attack):
		attack.set_player(self)
		_assign_weapon_refs()


func _assign_weapon_refs() -> void:
	if not is_instance_valid(attack):
		return

	if is_instance_valid(animation) and _weapon_has_property(attack, &"animation"):
		attack.set("animation", animation)

	if is_instance_valid(movement) and _weapon_has_property(attack, &"movement"):
		attack.set("movement", movement)


func _weapon_has_property(weapon: Object, property_name: StringName) -> bool:
	for prop in weapon.get_property_list():
		if prop.name == property_name:
			return true
	return false


func _detection_signals() -> void:
	# Connect signals for DETECTION node.
	# These get their own function because they are called in apply_role also.
	if not is_instance_valid(detection) or not is_instance_valid(tactical):
		return

	if tactical.has_method("set_target"):
		detection.connect("target_changed", Callable(tactical, "set_target"))

	if tactical.has_method("clear_target"):
		detection.connect("target_lost", Callable(tactical, "clear_target"))

	if tactical.has_method("detection_refreshed"):
		detection.connect("target_refreshed", Callable(tactical, "detection_refreshed"))


func _detection_disconnect_signals() -> void:
	# Disconnects signals for DETECTION node to old TACTICAL node.
	# These get their own function because they are called in apply_role also.
	if not is_instance_valid(detection) or not is_instance_valid(tactical):
		return

	if tactical.has_method("set_target"):
		detection.disconnect("target_changed", Callable(tactical, "set_target"))

	if tactical.has_method("clear_target"):
		detection.disconnect("target_lost", Callable(tactical, "clear_target"))

	if tactical.has_method("detection_refreshed"):
		detection.disconnect("target_refreshed", Callable(tactical, "detection_refreshed"))


func _tactical_signals() -> void:
	# Connect signals for TACTICAL node.	
	if not is_instance_valid(tactical):
		return

	if tactical.has_method("set_agent"):
		tactical.call("set_agent", self)

	if is_instance_valid(animation) and tactical.has_method("attack_finished"):
		animation.connect("actionAnimationFinished", Callable(tactical, "attack_finished"))

	if tactical.has_signal("chase_target"):
		if is_instance_valid(pathfinding):
			tactical.connect("chase_target", Callable(pathfinding, "stop_meander"))
			tactical.connect("chase_target", Callable(pathfinding, "set_chase_target"))

		if is_instance_valid(movement):
			tactical.connect("chase_target", Callable(movement, "stop_meander"))

	if tactical.has_signal("resume_patrol"):
		if is_instance_valid(pathfinding):
			tactical.connect("resume_patrol", Callable(pathfinding, "clear_target"))
			tactical.connect("resume_patrol", Callable(pathfinding, "stop_meander"))

		if is_instance_valid(movement):
			tactical.connect("resume_patrol", Callable(movement, "make_meander"))

	if tactical.has_signal("move_to_position"):
		if is_instance_valid(pathfinding):
			tactical.connect("move_to_position", Callable(pathfinding, "stop_meander"))
			tactical.connect("move_to_position", Callable(pathfinding, "set_move_target_position"))

		if is_instance_valid(movement):
			tactical.connect("move_to_position", Callable(movement, "stop_meander"))


func _tactical_disconnect_signals() -> void:
	# Disconnects signals for old TACTICAL node.	
	if not is_instance_valid(tactical):
		return

	if is_instance_valid(animation) and tactical.has_method("attack_finished"):
		animation.disconnect("actionAnimationFinished", Callable(tactical, "attack_finished"))

	if tactical.has_signal("chase_target"):
		if is_instance_valid(pathfinding):
			tactical.disconnect("chase_target", Callable(pathfinding, "stop_meander"))
			tactical.disconnect("chase_target", Callable(pathfinding, "set_chase_target"))

		if is_instance_valid(movement):
			tactical.disconnect("chase_target", Callable(movement, "stop_meander"))

	if tactical.has_signal("resume_patrol"):
		if is_instance_valid(pathfinding):
			tactical.disconnect("resume_patrol", Callable(pathfinding, "clear_target"))
			tactical.disconnect("resume_patrol", Callable(pathfinding, "stop_meander"))

		if is_instance_valid(movement):
			tactical.disconnect("resume_patrol", Callable(movement, "make_meander"))

	if tactical.has_signal("move_to_position"):
		if is_instance_valid(pathfinding):
			tactical.disconnect("move_to_position", Callable(pathfinding, "stop_meander"))
			tactical.disconnect("move_to_position", Callable(pathfinding, "set_move_target_position"))

		if is_instance_valid(movement):
			tactical.disconnect("move_to_position", Callable(movement, "stop_meander"))


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


#func _take_heal() -> void:
#	if is_instance_valid(animation):
#		animation.show_heal()


#func _no_interact_target() -> void:
#	if is_instance_valid(gold):
#		gold.drop_gold(1)


#func _returned_carry() -> void:
#	# Called when a carried object is detected to have been returned to castle.
#	carrying.delete_me()
#	if is_instance_valid(gold):
#		gold.pickup_gold(1)
#	carrying = null


#func _interaction_finished(interactingPlayer: int) -> void:
#	# Called when player interacts with minion. Should cancel task and assign the follow task for the player.
#	if !carrying:
#		if is_instance_valid(task):
#			task.remove_me(self)


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
		attack.queue_free()
		attack = null

	if is_instance_valid(tactical):
		_tactical_disconnect_signals()
		_detection_disconnect_signals()
		tactical.queue_free()
		tactical = null

	# --- add new weapon (PackedScene) ---
	var weapon_scene: PackedScene = UnitRoles.get_weapon(role)
	if weapon_scene != null:
		attack = weapon_scene.instantiate()
		add_child(attack)

		# Configure attack signals
		_attack_signals()
	
	# --- add new tactical (Script) ---
	var tactical_script: Script = UnitRoles.get_tactical(role)
	if tactical_script != null:
		tactical = tactical_script.new()
		add_child(tactical)

		# Configure tactical signals.
		_tactical_signals()

		# Reconfigure the signals from detection to tactical.
		_detection_signals()

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
