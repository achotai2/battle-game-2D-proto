extends StaticBody3D
class_name BuildingBase

signal new_castle_set(new_castle: Castle)

@export var player: int = 0
@export var castle: Castle
@export var building_type: BuildingDefs.BuildingType = BuildingDefs.BuildingType.BARRACKS

# --- The Components ---
@export var construct_interactable: Interactable
@export var spawn_interactable: Interactable
@export var construct_site: WorkSite
@export var production_queue: ProductionQueue
@export var visuals: BuildingVisuals 
@export var state: BuildingDefs.BuildingState = BuildingDefs.BuildingState.DESTROYED
@export var is_tree: bool = false

@export var building_visuals: BuildingVisuals = null
@export var construct_work_site: WorkSite = null
@export var food_job_board: Node = null
@export var gold_giver: GoldGiver = null
@export var gold_wallet: GoldWallet = null
@export var instantiator: Instantiator = null
@export var interactable: Interactable = null
@export var night_instantiator: NightInstantiator = null
@export var peasant_job_board: Node = null
@export var spawn_site: SpawnSite = null
@export var spawn_work_site: WorkSite = null
@export var team_memory: TeamMemory = null
@export var work_site: WorkSite = null
@export var worker_job_board: Node = null
@export var health: Health = null
@export var animated_sprite_3d: AnimatedSprite3D = null

func _ready() -> void:
	add_to_group("Buildings")

	# Initialize components
	building_visuals = ComponentFinder.get_component(self, "BuildingVisuals")
	construct_work_site = ComponentFinder.get_component_by_name(self, "ConstructWorkSite")
	food_job_board = ComponentFinder.get_component_by_name(self, "FoodJobBoard")
	gold_giver = ComponentFinder.get_component(self, "GoldGiver")
	gold_wallet = ComponentFinder.get_component(self, "GoldWallet")
	instantiator = ComponentFinder.get_component(self, "Instantiator")
	interactable = ComponentFinder.get_component(self, "Interactable")
	night_instantiator = ComponentFinder.get_component(self, "NightInstantiator")
	peasant_job_board = ComponentFinder.get_component_by_name(self, "PeasantJobBoard")
	spawn_site = ComponentFinder.get_component(self, "SpawnSite")
	spawn_work_site = ComponentFinder.get_component_by_name(self, "SpawnWorkSite")
	team_memory = ComponentFinder.get_component(self, "TeamMemory")
	work_site = ComponentFinder.get_component(self, "WorkSite")
	worker_job_board = ComponentFinder.get_component_by_name(self, "WorkerJobBoard")
	health = ComponentFinder.get_component(self, "Health")
	animated_sprite_3d = ComponentFinder.get_component(self, "AnimatedSprite3D")

	# Check if we are a tree before applying the physics layer!
	if is_tree:
		collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_TREES)
	else:
		collision_layer = GamePhysics.get_building_layer()
	
	if team_memory:
		team_memory.current_team = player

	# 1. Wire up the Construction Pipeline
	if construct_interactable:
		construct_interactable.interaction_finished.connect(_on_construct_clicked)
		
	if construct_site:
		construct_site.work_completed.connect(_on_construct_finished)
		# NEW: Listen for the exact moment hammers start swinging
		if construct_site.has_signal("work_started"):
			construct_site.work_started.connect(_on_work_started)

	# 2. Boot up the building
	set_state(state)

	# Force physics update on the next frame to trigger Area3D overlaps
	# This fixes a Godot 4 broadphase issue with StaticBody3Ds spawned from threads (like ProtonScatter)
	if not Engine.is_editor_hint():
		get_tree().physics_frame.connect(_force_physics_update, CONNECT_ONE_SHOT)


func _force_physics_update() -> void:
	if not is_inside_tree(): return
	var p = global_position
	global_position = p + Vector3.UP * 0.001
	force_update_transform()
	global_position = p
	force_update_transform()


# --- STATE MACHINE (THE SWITCHBOARD) ---

func set_state(new_state: BuildingDefs.BuildingState) -> void:
	state = new_state

	match state:
		BuildingDefs.BuildingState.DESTROYED:
			if spawn_interactable: spawn_interactable.set_enabled(false)
			if construct_site: construct_site.set_enabled(false)
			
			if construct_interactable:
				var cost = BuildingDefs.get_construction_cost(building_type)
				var icon = BuildingDefs.get_interact_mode(building_type, state)
				construct_interactable.update_interaction_state(icon, cost)
				construct_interactable.set_enabled(true)

		BuildingDefs.BuildingState.CONSTRUCTING:
			if construct_interactable: construct_interactable.set_enabled(false)
			if spawn_interactable: spawn_interactable.set_enabled(false)
			
			if construct_site:
				construct_site.total_work = BuildingDefs.get_construction_cost(building_type)
				construct_site.reset_progress()
				construct_site.set_enabled(true) 
				construct_site.refresh_registration()

		BuildingDefs.BuildingState.BUILDING:
			# The site is already active and workers are attached. 
			# We do absolutely nothing to the interactables or sites here!
			pass

		BuildingDefs.BuildingState.BUILT:
			if construct_interactable: construct_interactable.set_enabled(false)
			if construct_site: construct_site.set_enabled(false)
			
			if spawn_interactable:
				var config = BuildingDefs.get_spawn_config(building_type)
				var unit_type = config.get("unit_type", 0)
				var cost = BuildingDefs.get_unit_train_cost(unit_type)
				var icon = BuildingDefs.get_interact_mode(building_type, state)
				spawn_interactable.update_interaction_state(icon, cost)
				spawn_interactable.set_enabled(true)

	# Update the visuals at the very end of every state change
	if visuals:
		visuals.update_visuals(state, player)


# --- SIGNAL HANDLERS ---

func _on_construct_clicked(interactor: AgentBase) -> void:
	set_state(BuildingDefs.BuildingState.CONSTRUCTING)

func _on_work_started() -> void:
	# Only shift to BUILDING if we were waiting in the CONSTRUCTING state
	if state == BuildingDefs.BuildingState.CONSTRUCTING:
		set_state(BuildingDefs.BuildingState.BUILDING)

func _on_construct_finished(site: WorkSite, worker: AgentBase) -> void:
	set_state(BuildingDefs.BuildingState.BUILT)

func _on_destroyed() -> void:
	set_state(BuildingDefs.BuildingState.DESTROYED)


# --- PUBLIC GETTERS / SETTERS ---

func set_castle(new_castle: Castle) -> void:
	castle = new_castle
	new_castle_set.emit(new_castle)
	
	# Buildings to instantly adopt the castle's team color
	if is_instance_valid(castle) and player != castle.player:
		set_player(castle.player)


func return_castle() -> Castle:
	return castle
	
	
func set_player(p: int) -> void:
	player = p
	if team_memory:
		team_memory.current_team = p
	set_state(state) 


func return_position() -> Vector3:
	return global_position
