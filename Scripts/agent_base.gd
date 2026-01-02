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

var _desired_velocity: Vector2
var _desired_direction: Vector2
var _use_velocity: bool


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(interaction):
		interaction.noInteractTarget.connect(_no_interact_target)
		interaction.set_player(self, player)

	if is_instance_valid(interact):
		interact.update_time_step(false, false)
		interact.interactionFinished.connect(_interaction_finished)

	if is_instance_valid(animation):
		animation.animationFinished.connect(_animation_finished)

	if is_instance_valid(movement):
		movement.iMoved.connect(_agent_moved)
		
	if is_instance_valid(pathfinding):
		pathfinding.desired_velocity.connect(_on_pf_desired_velocity)

	if is_instance_valid(controls):
		controls.buildEngaged.connect(_build_engaged)
		controls.buildReleased.connect(_build_released)
		controls.moveAgent.connect(_controlled_movement)
		
	if is_instance_valid(attack):
		attack.attack_started.connect(_attack_started)
		attack.set_player(self, player)

	if is_instance_valid(detection):
		detection.target_changed.connect(_detected_target)
		detection.target_lost.connect(_detected_lost)
		detection.target_refreshed.connect(_detected_refreshed)
		detection.set_myself(self, player)

	if is_instance_valid(task):
		task.returnedCarry.connect(_returned_carry)
		
	if is_instance_valid(tactical):
		tactical.chase_target.connect(_on_chase_target)
		tactical.resume_patrol.connect(_on_resume_patrol)
		tactical.move_to_position.connect(_on_move_to_position)
		
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

	if is_instance_valid(movement):
		# Convert intent -> movement with the correct delta
		if _use_velocity:
			movement.move_with_velocity(_desired_velocity, _delta)
		else:
			movement.move_in_direction(_desired_direction, _delta)

	move_and_slide()


func _take_damage() -> void:
	if is_instance_valid(animation):
		animation.show_damage()


func _returned_carry() -> void:
	# Called when a carried object is detected to have been returned to castle.
	carrying.delete_me()
	if is_instance_valid(gold):
		gold.pickup_gold(1)
	carrying = null


func _interaction_finished(interactingPlayer: int) -> void:
	# Called when player interacts with minion. Should cancel task and assign the follow task for the player.
	if !carrying:
		if is_instance_valid(task):
			task.remove_me(self)


func _im_damaged() -> void:
	pass


func _im_dead() -> void:
	if current_role == "peasant" or current_role == "player":
		return
	else:
		apply_role("peasant", player)


func _take_heal() -> void:
	if is_instance_valid(animation):
		animation.show_heal()


func _no_interact_target() -> void:
	if is_instance_valid(gold):
		gold.drop_gold(1)


func _animation_finished() -> void:
	# Called by agent_animate to unfreeze movement when animation finished.
	if is_instance_valid(movement):
		movement.un_freeze()


func _agent_moved(vel: Vector2) -> void:
	if is_instance_valid(animation):
		animation.agent_moved(vel)
		
	self.velocity = vel


func _build_engaged() -> void:
	# Called by controls when build button depressed.
	if is_instance_valid(interaction):
		interaction.interaction_engaged()

	# Tell attack to stop attacking while build engaged.
	if is_instance_valid(attack):
		attack.player_controls_activated()


func _build_released() -> void:
	# Called by controls when build button released.
	if is_instance_valid(interaction):
		interaction.interaction_released()

	# Tell attack to stop attacking while build engaged.
	if is_instance_valid(attack):
		attack.player_controls_deactivated()


func _controlled_movement(dir: Vector2) -> void:
	# Called by controls when movement keys pressed.
	if is_instance_valid(movement):
		_desired_direction = dir
		_use_velocity = false

	# Tell attack to stop attacking if moving, or restart attacking if not moving.
	if is_instance_valid(attack):
		if dir == Vector2.ZERO:
			attack.player_controls_deactivated()
		else:
			attack.player_controls_activated()


func _on_pf_desired_velocity(v: Vector2) -> void:
	_desired_velocity = v  # store as intent
	_use_velocity = true


func _attack_started(target) -> void:
	if is_instance_valid(animation):
		animation.play_attack(target.return_position(), self.return_position())

	if is_instance_valid(movement):
		movement.freeze()


func _detected_target(target: Node2D) -> void:
	# Called by detection node.
	# Found an target, pass this on to tactical.
	if is_instance_valid(tactical):
		tactical.set_target(target)


func _detected_lost() -> void:
	# Called by detection node.
	if is_instance_valid(tactical):
		tactical.clear_target()


func _detected_refreshed(target: Node2D) -> void:
	# Called by detection node.
	if is_instance_valid(tactical):
		if target != null:
			tactical.set_target(target)
		else:
			tactical.clear_target()


func _on_chase_target(t: Node2D) -> void:
	# Called by signal from tactical.
	if is_instance_valid(pathfinding):
		pathfinding.set_meander(false)
		pathfinding.set_chase_target(t)

	if is_instance_valid(movement):
		movement.stop_meander()


func _on_resume_patrol() -> void:
	# Called by signal from tactical.
	if is_instance_valid(pathfinding):
		pathfinding.clear_target()
		pathfinding.set_meander(true)

	if is_instance_valid(movement):
		movement.make_meander()


func _on_move_to_position(pos: Vector2) -> void:
	# Called by signal from tactical.
	if is_instance_valid(pathfinding):
		pathfinding.set_meander(false)
		pathfinding.set_move_target_position(pos)

	if is_instance_valid(movement):
		movement.stop_meander()


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
		tactical.queue_free()
		tactical = null

	# --- add new weapon (PackedScene) ---
	var weapon_scene: PackedScene = UnitRoles.get_weapon(role)
	if weapon_scene != null:
		attack = weapon_scene.instantiate()
		add_child(attack)

		# Configure
		if attack.has_method("set_player"):
			attack.call("set_player", self, player)

		# Signals (weapon -> agent)
		if attack.has_signal("attack_started"):
			attack.connect("attack_started", Callable(self, "_attack_started"))

	# --- add new tactical (Script) ---
	var tactical_script: Script = UnitRoles.get_tactical(role)
	if tactical_script != null:
		tactical = tactical_script.new()
		add_child(tactical)

		# Optional configuration
		if tactical.has_method("set_castle"):
			tactical.call("set_castle", castle)

		# Signals (tactical -> agent)
		if tactical.has_signal("chase_target"):
			tactical.connect("chase_target", Callable(self, "_on_chase_target"))
		if tactical.has_signal("move_to_position"):
			tactical.connect("move_to_position", Callable(self, "_on_move_to_position"))
		if tactical.has_signal("resume_patrol"):
			tactical.connect("resume_patrol", Callable(self, "_on_resume_patrol"))

	# --- visuals ---
	var frames: SpriteFrames = UnitRoles.get_frames(role, player)
	if frames != null and is_instance_valid(animation):
		animation.set_sprite_frames(frames)

	# --- add new role groups ---
	for g: StringName in UnitRoles.get_role_groups(role):
		add_to_group(g)

	current_role = role

	# --- tracking refresh (optional) ---
	if is_instance_valid(detection):
		detection.refresh()

	if is_instance_valid(pathfinding):
		pathfinding.clear_target()

	# Cancel transient action states when swapping role
	if is_instance_valid(movement):
		movement.un_freeze()

	# If you have flags on animation like `attacking`, clear them too
	if is_instance_valid(animation) and animation.has_method("cancel_action_state"):
		animation.call("cancel_action_state")	


func return_player() -> int:
	return player


func return_position() -> Vector2:
	return self.global_position


func return_velocity() -> Vector2:
	return self.velocity


func is_idle() -> bool:
	return true


func return_castle() -> Node:
	return castle


func spawned_this_resource(spawned: Node) -> void:
	pass


func return_health() -> int:
	return 100 
	#if is_instance_valid(health):
		#return health.return_health()
	#else:
		#return 0


func delete_me() -> void:
	if is_instance_valid(task):
		task.remove_me(self)
	self.queue_free()


func return_to_castle() -> void:
	if is_instance_valid(castle):
		castle.give_me_task(self)


# Called by resource _body_entered when picked up by this agent.
func carry_me(thing: Node) -> void:
	thing.reparent(self)
	carrying = thing
	thing.global_position = self.global_position


func set_player(newPlayer: int, newCastle: Node, goldAmount: int) -> void:
	#playerUpdate.emit(newPlayer)
	player = newPlayer
	castle = newCastle
	if is_instance_valid(gold):
		gold.pickup_gold(goldAmount)


# PROBABLY BEST TO MOVE INTO SEPARATE BASES
func task_command(taskType: String, taskPlayer: int) -> void:
	# Called by tasks
	if self.is_in_group("Goblins") and taskType == "Gold":
		if is_instance_valid(gold):
			gold.pickup_gold(-1)
		set_player(taskPlayer, get_parent().get_closest_castle(taskPlayer, return_position()), 0)

	elif self.is_in_group("Goblins") and taskType == "Spawn":
		delete_me()


# Called by spawns when a unit is spawned from this unit.
func return_my_gold() -> int:
	if is_instance_valid(gold):
		return gold.return_gold()
	else:
		return 0
