extends CharacterBody3D
class_name AgentBase

signal new_castle_set(new_castle: Castle)

@export var player: int = 0
@export var movement: AgentMovement = null
@export var team: TeamMemory = null
@export var animate: AgentAnimate = null
@export var castle: Castle = null
@export var current_role: UnitRoles.UnitType
@export var death_effect_scene: PackedScene

@export var gold_giver: GoldGiver = null
@export var gold_wallet: GoldWallet = null
@export var minion_nav_agent: NavigationAgent3D = null
@export var tax_ledger: TaxLedger = null
@export var tracker: Node3D = null
@export var unit_speed: UnitSpeed = null
@export var a_attack: AdvisorAttack = null
@export var a_goblin_march: AdvisorGoblinMarch = null
@export var a_lord_tax: AdvisorLordTax = null
@export var a_player_interact: AdvisorPlayerInteract = null
@export var a_player_movement: AdvisorPlayerMovement = null
@export var a_taxed: AdvisorTaxed = null
@export var a_transform: AdvisorTransform = null
@export var a_wander: AdvisorWander = null
@export var a_work: AdvisorWork = null
@export var health: Health = null
@export var hunger_holder: HungerHolder = null
@export var minion_tasker: MinionTasker = null
@export var player_controls: PlayerControls = null
@export var player_interactor: Node3D = null
@export var weapon_bow: Node3D = null
@export var weapon_sword: Node3D = null
@export var work_action: WorkAction = null
@export var animated_sprite_3d: AnimatedSprite3D = null
@export var weapons_node: Node3D = null

@onready var brain: AgentBrain = $Brain
@onready var sensors: Node = $Sensors
@onready var motor: Node = $Motor
@onready var memory: Node = $Memory
@onready var weapons: Node = $Weapons



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not movement:
		movement = ComponentFinder.get_component(self, "AgentMovement")
	if not animate:
		animate = ComponentFinder.get_component(self, "AgentAnimate")
	if not team:
		team = ComponentFinder.get_component(self, "TeamMemory")

	gold_giver = ComponentFinder.get_component(self, "GoldGiver")
	gold_wallet = ComponentFinder.get_component(self, "GoldWallet")
	minion_nav_agent = ComponentFinder.get_component_by_name(self, "MinionNavAgent")
	tax_ledger = ComponentFinder.get_component(self, "TaxLedger")
	tracker = ComponentFinder.get_component_by_name(self, "Tracker")
	unit_speed = ComponentFinder.get_component(self, "UnitSpeed")
	a_attack = ComponentFinder.get_component(self, "AdvisorAttack")
	a_goblin_march = ComponentFinder.get_component(self, "AdvisorGoblinMarch")
	a_lord_tax = ComponentFinder.get_component(self, "AdvisorLordTax")
	a_player_interact = ComponentFinder.get_component(self, "AdvisorPlayerInteract")
	a_player_movement = ComponentFinder.get_component(self, "AdvisorPlayerMovement")
	a_taxed = ComponentFinder.get_component(self, "AdvisorTaxed")
	a_transform = ComponentFinder.get_component(self, "AdvisorTransform")
	a_wander = ComponentFinder.get_component(self, "AdvisorWander")
	a_work = ComponentFinder.get_component(self, "AdvisorWork")
	health = ComponentFinder.get_component(self, "Health")
	hunger_holder = ComponentFinder.get_component(self, "HungerHolder")
	minion_tasker = ComponentFinder.get_component(self, "MinionTasker")
	player_controls = ComponentFinder.get_component(self, "PlayerControls")
	player_interactor = ComponentFinder.get_component_by_name(self, "player_interactor")
	weapon_bow = ComponentFinder.get_component_by_name(self, "weapon_bow")
	weapon_sword = ComponentFinder.get_component_by_name(self, "weapon_sword")
	work_action = ComponentFinder.get_component(self, "WorkAction")
	animated_sprite_3d = ComponentFinder.get_component(self, "AnimatedSprite3D")
	weapons_node = ComponentFinder.get_component(self, "Node3D", "Weapons")

	if team:
		team.current_team = player
	
	apply_role(current_role, team.return_team() if team else player)
	
	_register_myself_with_castle()


func _exit_tree() -> void:
	_unregister_myself_with_castle()


func _physics_process(_delta: float) -> void:
	if movement:
		movement.tick(_delta)

	move_and_slide()


func _im_damaged() -> void:
#	if animation:
#		animation.show_damage()
	pass


func _im_dead() -> void:
	if current_role == UnitRoles.UnitType.PEASANT or current_role == UnitRoles.UnitType.PLAYER:
		return
		
	elif current_role == UnitRoles.UnitType.GOBLIN:
		# 1. Spawn the bone pile
		if death_effect_scene:
			var effect = death_effect_scene.instantiate() as Node3D
			
			# 2. Add it to the main world so it survives the Goblin's death
			get_tree().current_scene.add_child(effect)
			
			# 3. Drop it at the Goblin's exact coordinates
			effect.global_position = self.global_position
			
		# 4. Destroy the Goblin
		queue_free()
		
	else:
		apply_role(UnitRoles.UnitType.PEASANT, team.return_team())


func _agent_moved(vel: Vector3) -> void:
	# Called by signal from movement when movement occurs.
	self.velocity = vel


##################
# External called.
##################
func apply_role(role: UnitRoles.UnitType, new_team: int) -> void:
	# --- 1. COMPONENT SYNC (The Diff & Sync Architecture) ---
	# Ask the factory for the packaged components for the new role
	var components = UnitRoles.get_role_components(role)
	
	# Intelligently prune and plant nodes in their respective folders
	_sync_folder(memory, components["memory"])
	_sync_folder(sensors, components["sensors"])
	_sync_folder(weapons, components["weapons"])
	_sync_folder(motor, components["motor"])
	_sync_folder(brain, components["advisors"])

	# Tell the brain to introduce itself to the new advisors.
	if brain and brain.has_method("refresh_advisors"):
		brain.refresh_advisors()

	# Set the new variables.
	movement = ComponentFinder.get_component(self, "AgentMovement") as AgentMovement
	team = ComponentFinder.get_component(self, "TeamMemory") as TeamMemory
	animate = ComponentFinder.get_component(self, "AgentAnimate") as AgentAnimate

	gold_giver = ComponentFinder.get_component(self, "GoldGiver") as GoldGiver
	gold_wallet = ComponentFinder.get_component(self, "GoldWallet") as GoldWallet
	minion_nav_agent = ComponentFinder.get_component_by_name(self, "MinionNavAgent") as NavigationAgent3D
	tax_ledger = ComponentFinder.get_component(self, "TaxLedger") as TaxLedger
	tracker = ComponentFinder.get_component_by_name(self, "Tracker") as Node3D
	unit_speed = ComponentFinder.get_component(self, "UnitSpeed") as UnitSpeed
	a_attack = ComponentFinder.get_component(self, "AdvisorAttack") as AdvisorAttack
	a_goblin_march = ComponentFinder.get_component(self, "AdvisorGoblinMarch") as AdvisorGoblinMarch
	a_lord_tax = ComponentFinder.get_component(self, "AdvisorLordTax") as AdvisorLordTax
	a_player_interact = ComponentFinder.get_component(self, "AdvisorPlayerInteract") as AdvisorPlayerInteract
	a_player_movement = ComponentFinder.get_component(self, "AdvisorPlayerMovement") as AdvisorPlayerMovement
	a_taxed = ComponentFinder.get_component(self, "AdvisorTaxed") as AdvisorTaxed
	a_transform = ComponentFinder.get_component(self, "AdvisorTransform") as AdvisorTransform
	a_wander = ComponentFinder.get_component(self, "AdvisorWander") as AdvisorWander
	a_work = ComponentFinder.get_component(self, "AdvisorWork") as AdvisorWork
	health = ComponentFinder.get_component(self, "Health") as Health
	hunger_holder = ComponentFinder.get_component(self, "HungerHolder") as HungerHolder
	minion_tasker = ComponentFinder.get_component(self, "MinionTasker") as MinionTasker
	player_controls = ComponentFinder.get_component(self, "PlayerControls") as PlayerControls
	player_interactor = ComponentFinder.get_component_by_name(self, "player_interactor") as Node3D
	weapon_bow = ComponentFinder.get_component_by_name(self, "weapon_bow") as Node3D
	weapon_sword = ComponentFinder.get_component_by_name(self, "weapon_sword") as Node3D
	work_action = ComponentFinder.get_component(self, "WorkAction") as WorkAction
	animated_sprite_3d = ComponentFinder.get_component(self, "AnimatedSprite3D") as AnimatedSprite3D
	weapons_node = ComponentFinder.get_component(self, "Node3D", "Weapons") as Node3D

	if is_instance_valid(health):
		if not health.damaged.is_connected(_im_damaged):
			health.damaged.connect(_im_damaged)
		if not health.died.is_connected(_im_dead):
			health.died.connect(_im_dead)

	# Tell the movement node to find the newly generated NavAgent.
	if is_instance_valid(movement) and movement.has_method("refresh_components"):
		movement.refresh_components()

	# --- 2. TEAM & PHYSICS ---
	# Set the new player number (assuming 'team' is an @onready or fetched component)
	if team != null:
		team.current_team = new_team

	# Apply the new collision mask and layer
	collision_layer = GamePhysics.get_minion_layer(new_team, role == UnitRoles.UnitType.PEASANT)
	collision_mask = GamePhysics.get_minion_movement_mask()

	# --- 3. GROUP MEMBERSHIP ---
	# Remove old role groups before we update the current_role variable.
	if current_role != null:
		for g: StringName in UnitRoles.get_role_groups(current_role):
			if is_in_group(g):
				remove_from_group(g)

	# Update the state
	current_role = role

	# Add new role groups.
	for g: StringName in UnitRoles.get_role_groups(current_role):
		add_to_group(g)

	# --- 4. VISUALS ---
	# This ensures your Chinese painting aesthetic sprite frames update 
	# smoothly without flickering when the unit changes roles.
	var frames: SpriteFrames = UnitRoles.get_frames(current_role, new_team)
	if frames != null and animate:
		animate.set_sprite_frames(frames)

	# --- 5. STATE REFRESH ---
	# Cancel transient action states when swapping role to prevent sliding or ghost attacks
	if movement:
		movement.stop()

	if animate:
		animate.cancel_action_state()
		
	if brain:
		brain._ready()


func _sync_folder(target_parent: Node, incoming_packages: Array) -> void:
# --- APPLY_ROLE HELPER FUNCTION ---
	if target_parent == null: return
	
	# Build a list of the names we EXPECT to have
	var incoming_names: Array[String] = []
	for package in incoming_packages:
		incoming_names.append(package["name"])
		
	# PHASE 1: PRUNE THE OLD
# PHASE 1: PRUNE THE OLD
	for existing_child in target_parent.get_children():
		# Ignore internal utility nodes like Timers!
		if existing_child is Timer:
			continue
			
		if not existing_child.name in incoming_names:
			existing_child.queue_free()
			
	# Update list of what survived the pruning
	var surviving_names: Array[String] = []
	for child in target_parent.get_children():
		if not child.is_queued_for_deletion(): 
			surviving_names.append(child.name)
			
	# PHASE 2: PLANT THE NEW
	for package in incoming_packages:
		var clean_name = package["name"]
		var generated_node = package["node"]
		
		if clean_name in surviving_names:
			var old_node = target_parent.get_node(clean_name)
			# If the component has a specific setter, update the old node 
			# using the newly manufactured node's data before we trash it!
			if old_node.has_method("set_job_board_kind") and "kind" in generated_node:
				old_node.set_job_board_kind(generated_node.kind)

			# We already have this component, trash the duplicate
			generated_node.free() 
		else:
			# It's new, attach it cleanly
			generated_node.name = clean_name
			target_parent.add_child(generated_node)


func return_player() -> int:
	if team:
		return team.return_team()
	else:
		return -1


func return_position() -> Vector3:
	return self.global_position


func return_velocity() -> Vector3:
	return self.velocity


#func is_idle() -> bool:
#	return true


# --- CASTLE ASSIGNMENT ---

func return_castle() -> Castle:
	return castle


# Called externally to update castle agent is assigned to.
func set_castle(new_castle: Node) -> void:
	_unregister_myself_with_castle()
	castle = new_castle
	_register_myself_with_castle()
	new_castle_set.emit(new_castle)


func _register_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.register_minion(self)


func _unregister_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.unregister_minion(self)
