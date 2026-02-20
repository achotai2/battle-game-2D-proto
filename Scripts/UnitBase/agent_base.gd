extends CharacterBody3D
class_name AgentBase

## Player number (0 = neutral).
@export var player: int = 0
@export var health: Health = null
@export var interactor: PlayerInteractor = null
@export var movement: AgentMovement = null
@export var controls: PlayerControls = null
@export var animation: AgentAnimate = null
@export var attack: Node = null
@export var interactable: Node = null
@export var detection: AgentTracking = null
@export var brain: AgentBrain = null
@export var tasker: MinionTasker = null
@export var gold: GoldHolder = null
@export var hunger: HungerHolder = null
@export var foodTasker: MinionTasker = null
@export var castle: Castle = null
@export var current_role: UnitRoles.UnitType


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_connect_all_refs()
	apply_role(current_role, player)
	
	_register_myself_with_castle()


func _exit_tree() -> void:
	_unregister_myself_with_castle()


func _connect_all_refs() -> void:
	# Connect signals for ANIMATION node.
	_assign_animation_refs()

	# Connect signals for MOVEMENT node.
	_assign_movement_refs()

	# Connect signals for player CONTROLS node.
	_assign_controls_refs()

	# Configure ATTACK node.	
	_assign_weapon_refs()

	# Connect signals for DETECTION node.
	_assign_detection_refs()

	# Connect signals for TASKER node.	
	_assign_tasker_refs()

	# Connect signals for FOOD TASKER node.	
	_assign_food_tasker_refs()

	# Connect signals for GOLD node.	
	_assign_gold_refs()

	# Connect signals for HEALTH node.	
	_assign_health_refs()

	# Connect signals for HUNGER node.	
	_assign_hunger_refs()


func _physics_process(_delta: float) -> void:
	if movement:
		movement.tick(_delta)

	move_and_slide()


func _assign_weapon_refs() -> void:
	if not attack:
		return

	attack.set_player(self)

	if movement and attack and attack.has_method("set_movement"):
		attack.call("set_movement", movement)


func _disconnect_weapon_signals() -> void:
	if not attack:
		return


func _assign_animation_refs() -> void:
	if not animation:
		return

	animation.set_my_agent(self)


func _assign_movement_refs() -> void:
	if not movement:
		return

	movement.agent = self
	movement.animation = animation

	if is_instance_valid(castle):
		movement.assigned_castle = castle


func _assign_controls_refs() -> void:
	if not controls:
		return
	
	controls.set_interactor(interactor)
	controls.set_attackNode(attack)
	controls.set_movement(movement)


func _assign_detection_refs() -> void:
	if not detection:
		return

	detection.setup_player(player)


func _assign_tasker_refs() -> void:
	if not tasker:
		return

	tasker.set_agent(self)
	tasker.set_movement(movement)
	# Signals disconnected, Tasker is passive.


func _assign_food_tasker_refs() -> void:
	if not foodTasker:
		return

	foodTasker.set_agent(self)
	foodTasker.set_movement(movement)


func _assign_gold_refs() -> void:
	if not gold:
		return
	
	if gold.has_method("set_movement") and not is_in_group("Player"):
		gold.call("set_movement", movement)
	else:
		pass
		# print_debug("No function set_movement in gold.")


func _assign_health_refs() -> void:
	if not health:
		return

	if not health.damaged.is_connected(_im_damaged):
		health.damaged.connect(_im_damaged)
	if not health.died.is_connected(_im_dead):
		health.died.connect(_im_dead)


func _assign_hunger_refs() -> void:
	if not hunger:
		return
		
	if movement and hunger.has_method("set_movement"):
		hunger.call("set_movement", movement)


func _im_damaged() -> void:
#	if animation:
#		animation.show_damage()
	pass


func _im_dead() -> void:
	if current_role == UnitRoles.UnitType.PEASANT or UnitRoles.UnitType.PLAYER:
		return
	else:
		apply_role(UnitRoles.UnitType.PEASANT, player)


func _agent_moved(vel: Vector3) -> void:
	# Called by signal from movement when movement occurs.
	self.velocity = vel


##################
# External called.
##################
func apply_role(role: UnitRoles.UnitType, p: int) -> void:
	# Set the new player number.
	player = p

	collision_layer = GamePhysics.get_minion_layer(player, role == UnitRoles.UnitType.PEASANT)
	collision_mask = GamePhysics.get_minion_movement_mask()

	# --- remove old role groups ---
	if current_role != null:
		for g: StringName in UnitRoles.get_role_groups(current_role):
			if is_in_group(g):
				remove_from_group(g)

	# --- remove old role-dependent nodes ---
	if attack:
		_disconnect_weapon_signals()
		attack.queue_free()
		attack = null

	if brain:
		brain.queue_free()
		brain = null

	if tasker:
		if tasker.has_task():
			tasker.clear_task()
			tasker.unregister_from_board()
		tasker.queue_free()
		tasker = null

	# --- add new weapon (PackedScene) ---
	var weapon_scene: PackedScene = UnitRoles.get_weapon(role)
	if weapon_scene != null:
		attack = weapon_scene.instantiate()
		add_child(attack)

	# --- add new tasker (Script) ---
	var tasker_script: Script = UnitRoles.get_tasker(role)
	if tasker_script != null:
		tasker = tasker_script.new()
		var kind = UnitRoles.get_tasker_kind(role)
		if kind != null and "kind" in tasker:
			tasker.kind = kind
		add_child(tasker)

	# --- add new Brain and Advisors ---
	brain = AgentBrain.new()
	brain.name = "Brain"
	brain.agent = self
	add_child(brain)

	if role == UnitRoles.UnitType.PLAYER:
		var adv = AdvisorPlayer.new()
		brain.add_child(adv)

		# Player can also auto-attack if weapon exists
		if attack:
			var att = AdvisorAttack.new()
			brain.add_child(att)
	else:
		var wander = AdvisorWander.new()
		brain.add_child(wander)

		if attack:
			var att = AdvisorAttack.new()
			brain.add_child(att)

		if tasker:
			var wrk = AdvisorWork.new()
			brain.add_child(wrk)

		if role == UnitRoles.UnitType.PEASANT or role == UnitRoles.UnitType.WORKER:
			var flee = AdvisorFlee.new()
			brain.add_child(flee)

	# --- visuals ---
	var frames: SpriteFrames = UnitRoles.get_frames(role, player)
	if frames != null and animation:
		animation.set_sprite_frames(frames)

	# --- add new role groups ---
	for g: StringName in UnitRoles.get_role_groups(role):
		add_to_group(g)

	current_role = role

	# Configure all refs.
	_connect_all_refs()

	# --- movement and animation refresh ---
	# Cancel transient action states when swapping role
	if movement:
		movement.clear_movement_order(9999)

	# If you have flags on animation like `attacking`, clear them too
	if animation:
		animation.cancel_action_state()


func return_player() -> int:
	return player


func return_position() -> Vector3:
	return self.global_position


func return_velocity() -> Vector3:
	return self.velocity


#func is_idle() -> bool:
#	return true


func return_castle() -> Node:
	return castle


# Called externally to update castle agent is assigned to.
func set_castle(new_castle: Node) -> void:
	_unregister_myself_with_castle()
	castle = new_castle
	_register_myself_with_castle()
	
	if movement:
		movement.assigned_castle = castle

	if tasker:
		tasker.switch_job_board(castle)

	if foodTasker:
		foodTasker.switch_job_board(castle)
		


func _register_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.register_minion(self)


func _unregister_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.unregister_minion(self)
