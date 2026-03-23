extends CharacterBody3D
class_name AgentBase

signal new_castle_set(new_castle: Castle)

# --- THE FIX: REACTIVE VARIABLE ---
@export var player: int = 0:
	set(value):
		player = value # Store it just in case TeamMemory isn't loaded yet
		if is_instance_valid(team):
			team.current_team = value
	get:
		if is_instance_valid(team):
			return team.return_team()
		return player

@export var movement: AgentMovement = null
@export var team: TeamMemory = null
@export var animate: AgentAnimate = null
@export var castle: Castle = null
@export var current_role: UnitRoles.UnitType = UnitRoles.UnitType.PEASANT
@export var death_effect_scene: PackedScene

var gold_giver: GoldGiver = null
var gold_wallet: GoldWallet = null
var minion_nav_agent: NavigationAgent3D = null
var tax_ledger: TaxLedger = null
var tracker: Node3D = null
var unit_speed: UnitSpeed = null
var health: Health = null
var hunger_holder: HungerHolder = null
var minion_tasker: MinionTasker = null
var player_controls: PlayerControls = null
var player_interactor: Node3D = null
var weapon_bow: Node3D = null
var weapon_sword: Node3D = null
var work_action: WorkAction = null
var animated_sprite_3d: AnimatedSprite3D = null
var weapons_node: Node3D = null
var target_memory: Node = null
var _pending_target: Node3D = null

@onready var brain: AgentBrain = $Brain
@onready var sensors: Node = $Sensors
@onready var motor: Node = $Motor
@onready var memory: Node = $Memory
@onready var weapons: Node = $Weapons


func _ready() -> void:
	_cache_components()

	# Because of our new setter, we push the Editor's initial 'player' value directly into TeamMemory
	if team:
		team.current_team = player
	
	apply_role(current_role, player)
	
	_register_myself_with_castle()


# --- NEW: Single Source of Truth for Variables ---
func _cache_components() -> void:
	movement = ComponentFinder.get_component(self, "AgentMovement") as AgentMovement
	animate = ComponentFinder.get_component(self, "AgentAnimate") as AgentAnimate
	team = ComponentFinder.get_component(self, "TeamMemory") as TeamMemory
	gold_giver = ComponentFinder.get_component(self, "GoldGiver") as GoldGiver
	gold_wallet = ComponentFinder.get_component(self, "GoldWallet") as GoldWallet
	minion_nav_agent = ComponentFinder.get_component_by_name(self, "MinionNavAgent") as NavigationAgent3D
	tax_ledger = ComponentFinder.get_component(self, "TaxLedger") as TaxLedger
	tracker = ComponentFinder.get_component_by_name(self, "Tracker") as Node3D
	unit_speed = ComponentFinder.get_component(self, "UnitSpeed") as UnitSpeed
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
	target_memory = ComponentFinder.get_component(self, "TargetMemory") as TargetMemory

	# Wire up health signals immediately after finding the health component
	if is_instance_valid(health):
		if not health.damaged.is_connected(_im_damaged):
			health.damaged.connect(_im_damaged)
		if not health.died.is_connected(_im_dead):
			health.died.connect(_im_dead)
	
	# Explicitly setup the movement node so it doesn't have to search!
	if is_instance_valid(movement) and movement.has_method("setup"):
		movement.setup(self, animate, minion_nav_agent)


func _exit_tree() -> void:
	_unregister_myself_with_castle()


func _physics_process(_delta: float) -> void:
	if movement:
		movement.tick(_delta)
	move_and_slide()


func _im_damaged() -> void:
	pass


func _im_dead() -> void:
	if current_role == UnitRoles.UnitType.PEASANT or current_role == UnitRoles.UnitType.PLAYER:
		return
		
	elif current_role == UnitRoles.UnitType.GOBLIN:
		if death_effect_scene:
			var effect = death_effect_scene.instantiate() as Node3D
			get_tree().current_scene.add_child(effect)
			effect.global_position = self.global_position
		queue_free()
		
	else:
		apply_role(UnitRoles.UnitType.PEASANT, player)


func _agent_moved(vel: Vector3) -> void:
	self.velocity = vel


func apply_role(role: UnitRoles.UnitType, new_team: int) -> void:
	# Forces the role swap to wait until the current frame finishes, preventing physics deadlocks!
	call_deferred("_deferred_apply_role", role, new_team)


func _deferred_apply_role(role: UnitRoles.UnitType, new_team: int) -> void:
	# 1. Sync the Component Folders
	# We swap out the old logic blocks for the new ones.
	var components = UnitRoles.get_role_components(role)
	_sync_folder(memory, components["memory"])
	_sync_folder(sensors, components["sensors"])
	_sync_folder(weapons, components["weapons"])
	_sync_folder(motor, components["motor"])
	_sync_folder(brain, components["advisors"])

	# 2. THE CRITICAL PAUSE
	# We must wait exactly one physics frame. This gives Godot time to actually 
	# execute the queue_free() on the old nodes, add the new nodes to the scene tree,
	# and sync the NavigationServer for the new MinionNavAgent.
	await get_tree().physics_frame

	# 3. Re-cache the variables
	# Now that the dust has settled, ComponentFinder will grab the correct, newly added nodes.
	_cache_components()

	# --- THE TIMELINE FIX (MOVED UP) ---
	# 4. Team & Physics
	# Set the truth BEFORE waking up the components!
	player = new_team # This triggers our setter, automatically updating TeamMemory!

	collision_layer = GamePhysics.get_minion_layer(new_team, role == UnitRoles.UnitType.PEASANT)
	collision_mask = GamePhysics.get_minion_movement_mask()

	# 5. Re-activate logic AFTER recaching & setting the team
	# This ensures new components have access to the correctly cached variables on the AgentBase
	# and that they know exactly what team they are on.
	_activate_folder(memory)
	_activate_folder(sensors)
	_activate_folder(weapons)
	_activate_folder(motor)
	# ------------------------------------

	# 6. Refresh Internal Components (The Advisor Fix)
	if brain and brain.has_method("refresh_advisors"):
		# Passing 'self' here is crucial so the brain can hand the AgentBase 
		# reference down to the new advisors, allowing them to access unit_speed!
		brain.refresh_advisors(self)

	if is_instance_valid(movement) and movement.has_method("refresh_components"):
		movement.refresh_components()

	# 7. Group Membership
	if current_role != null:
		for g: StringName in UnitRoles.get_role_groups(current_role):
			if is_in_group(g):
				remove_from_group(g)

	current_role = role

	for g: StringName in UnitRoles.get_role_groups(current_role):
		add_to_group(g)

	# 8. Visuals
	var frames: SpriteFrames = UnitRoles.get_frames(current_role, new_team)
	if frames != null and animate:
		animate.set_sprite_frames(frames)

# 9. State Refresh
	if is_instance_valid(movement):
		movement.stop()
	if is_instance_valid(animate):
		animate.cancel_action_state()
		
	# --- 10. FLUSH THE INBOX ---
	# Now that we are fully awake, check if anyone gave us orders while we slept!
	if _pending_target != null:
		assign_target(_pending_target)
		_pending_target = null
		

func _sync_folder(target_parent: Node, incoming_packages: Array) -> void:
	if target_parent == null: return
	
	var incoming_names: Array[String] = []
	for package in incoming_packages:
		incoming_names.append(package["name"])
		
	for existing_child in target_parent.get_children():
		if existing_child is Timer:
			continue

		if existing_child.has_method("deactivate"):
			existing_child.deactivate()

		if not existing_child.name in incoming_names:
			# Prevent ComponentFinder from accidentally grabbing a dying ghost!
			existing_child.name = existing_child.name + "_DELETED"
			existing_child.queue_free()
				
	var surviving_names: Array[String] = []
	for child in target_parent.get_children():
		if not child.is_queued_for_deletion(): 
			surviving_names.append(child.name)
			
	for package in incoming_packages:
		var clean_name = package["name"]
		var generated_node = package["node"]
		
		if clean_name in surviving_names:
			var old_node = target_parent.get_node(clean_name)
			if old_node.has_method("set_job_board_kind") and "kind" in generated_node:
				old_node.set_job_board_kind(generated_node.kind)
			generated_node.free() 
		else:
			generated_node.name = clean_name
			target_parent.add_child(generated_node)


func return_player() -> int:
	return player

func return_position() -> Vector3:
	return self.global_position

func return_velocity() -> Vector3:
	return self.velocity

func return_castle() -> Castle:
	return castle

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

func _activate_folder(target_parent: Node) -> void:
	if target_parent == null: return
	for child in target_parent.get_children():
		if not child.is_queued_for_deletion() and child.has_method("activate"):
			child.activate()

func assign_target(target: Node3D) -> void:
	# If we are fully awake and have the memory node, do it instantly.
	if is_instance_valid(target_memory) and target_memory.has_method("set_target"):
		target_memory.set_target(target)
	else:
		# If we are still building ourselves, put it in the inbox for later!
		_pending_target = target
