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
@export var environmentRadar: EnvironmentRadar
@export var state: BuildingDefs.BuildingState = BuildingDefs.BuildingState.DESTROYED
@export var buildingDeath: BuildingDeath

var building_visuals: BuildingVisuals = null
var construct_work_site: WorkSite = null
var food_job_board: Node = null
var gold_giver: GoldGiver = null
var gold_wallet: GoldWallet = null
var instantiator: Instantiator = null
var interactable: Interactable = null
var night_instantiator: NightInstantiator = null
var peasant_job_board: Node = null
var spawn_site: SpawnSite = null
var spawn_work_site: WorkSite = null
var team_memory: TeamMemory = null
var work_site: WorkSite = null
var worker_job_board: Node = null
var health: Health = null
var animated_sprite_3d: AnimatedSprite3D = null

func _ready() -> void:
	add_to_group("Buildings")

	# 1. Grab all components cleanly
	_cache_components()

	# Check if we are a tree before applying the physics layer!
	if building_type == BuildingDefs.BuildingType.TREE:
		collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_TREES)
	else:
		collision_layer = GamePhysics.get_building_layer()
	
	if team_memory:
		team_memory.current_team = player

	# 2. Wire up the Construction Pipeline
	if construct_interactable:
		construct_interactable.interaction_finished.connect(_on_construct_clicked)
		
	if construct_site:
		construct_site.work_completed.connect(_on_construct_finished)
		if construct_site.has_signal("work_started"):
			construct_site.work_started.connect(_on_work_started)

	# 3. Boot up the building
	set_state(state)

	# Force physics update on the next frame to trigger Area3D overlaps
	if not Engine.is_editor_hint():
		get_tree().physics_frame.connect(_force_physics_update, CONNECT_ONE_SHOT)


func _cache_components() -> void:
	building_visuals = ComponentFinder.get_component(self, "BuildingVisuals") as BuildingVisuals
	construct_work_site = ComponentFinder.get_component_by_name(self, "ConstructWorkSite") as WorkSite
	food_job_board = ComponentFinder.get_component_by_name(self, "FoodJobBoard")
	gold_giver = ComponentFinder.get_component(self, "GoldGiver") as GoldGiver
	gold_wallet = ComponentFinder.get_component(self, "GoldWallet") as GoldWallet
	instantiator = ComponentFinder.get_component(self, "Instantiator") as Instantiator
	interactable = ComponentFinder.get_component(self, "Interactable") as Interactable
	night_instantiator = ComponentFinder.get_component(self, "NightInstantiator") as NightInstantiator
	peasant_job_board = ComponentFinder.get_component_by_name(self, "PeasantJobBoard")
	spawn_site = ComponentFinder.get_component(self, "SpawnSite")
	spawn_work_site = ComponentFinder.get_component_by_name(self, "SpawnWorkSite") as WorkSite
	team_memory = ComponentFinder.get_component(self, "TeamMemory") as TeamMemory
	work_site = ComponentFinder.get_component(self, "WorkSite") as WorkSite
	worker_job_board = ComponentFinder.get_component_by_name(self, "WorkerJobBoard")
	health = ComponentFinder.get_component(self, "Health") as Health
	animated_sprite_3d = ComponentFinder.get_component(self, "AnimatedSprite3D") as AnimatedSprite3D


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
			if construct_interactable:
				var cost = BuildingDefs.get_building_gold_cost(building_type) 
				construct_interactable.update_interaction_state(BuildingDefs.IconType.CONSTRUCT, cost) 
				construct_interactable.activate()

			if construct_site: construct_site.activate()			
			if spawn_interactable: spawn_interactable.deactivate()
			if spawn_work_site: spawn_work_site.deactivate()
			if spawn_site: spawn_site.deactivate()
			if work_site: work_site.deactivate()
			if production_queue: production_queue.deactivate()
			
		BuildingDefs.BuildingState.CONSTRUCTING:
			if construct_interactable: construct_interactable.deactivate()
			if spawn_interactable: spawn_interactable.deactivate()
			if spawn_work_site: spawn_work_site.deactivate()
			if spawn_site: spawn_site.deactivate()
			if work_site: work_site.deactivate()
			if production_queue: production_queue.deactivate()
			
			if construct_site:
				# --- Using the 'Work' getter so it doesn't crash! ---
				construct_site.total_work = BuildingDefs.get_construction_work(building_type)
				construct_site.reset_progress()
				construct_site.activate()
				construct_site.refresh_registration()

		BuildingDefs.BuildingState.BUILDING:
			pass

		BuildingDefs.BuildingState.BUILT:
			if construct_interactable: construct_interactable.deactivate()
			if construct_site: construct_site.deactivate()
			if work_site: work_site.activate()
			if production_queue: production_queue.activate()
			
			if spawn_interactable:
				var config = BuildingDefs.get_spawn_config(building_type)
				var unit_type = config.get("unit_type", 0)
				var cost = BuildingDefs.get_unit_gold_cost(unit_type)
				var icon = BuildingDefs.get_interact_mode(building_type, state)
				
				spawn_interactable.update_interaction_state(icon, cost)
				spawn_interactable.activate()

			# Check radar immediately upon finishing construction (Crucial for Trees!)
			if is_instance_valid(environmentRadar):
				environmentRadar.force_scan()
				
			# If I am a tree, tell all radars across the entire map exactly where I died
			if building_type == BuildingDefs.BuildingType.TREE and buildingDeath:
				buildingDeath.trigger_death()
				
	if visuals:
		visuals.update_visuals(state, player)


# --- SIGNAL HANDLERS ---

func _on_construct_clicked(_interactor: AgentBase) -> void:
	set_state(BuildingDefs.BuildingState.CONSTRUCTING)

func _on_work_started() -> void:
	if state == BuildingDefs.BuildingState.CONSTRUCTING:
		set_state(BuildingDefs.BuildingState.BUILDING)

func _on_construct_finished(_site: WorkSite, _worker: AgentBase) -> void:
	set_state(BuildingDefs.BuildingState.BUILT)


# --- PUBLIC GETTERS / SETTERS ---

func set_castle(new_castle: Castle) -> void:
	castle = new_castle
	new_castle_set.emit(new_castle)
	
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
