extends CharacterBody3D
class_name AgentBase

@export var movement: AgentMovement = null
@export var team: TeamMemory = null
@export var animate: AgentAnimate = null
@export var castle: Castle = null
@export var current_role: UnitRoles.UnitType

@onready var brain: AgentBrain = $Brain
@onready var sensors: Node = $Sensors
@onready var motor: Node = $Motor
@onready var memory: Node = $Memory
@onready var weapons: Node = $Weapons
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not movement:
		movement = find_child("AgentMovement")

	if not animate:
		animate = find_child("AgentAnimate")

	if not team:
		team = find_child("TeamMemory")
	
	apply_role(current_role, team.return_team())
	
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

	# Tell the brain to introduce itself to the new advisors!
	if brain and brain.has_method("refresh_advisors"):
		brain.refresh_advisors()


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


func return_castle() -> Node:
	return castle


# Called externally to update castle agent is assigned to.
func set_castle(new_castle: Node) -> void:
	_unregister_myself_with_castle()
	castle = new_castle
	_register_myself_with_castle()


func _register_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.register_minion(self)


func _unregister_myself_with_castle() -> void:
	if is_instance_valid(castle):
		castle.unregister_minion(self)
