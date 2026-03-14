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

var _team_memory: Node = null


func _ready() -> void:
	# Check if we are a tree before applying the physics layer!
	if is_tree:
		collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_TREES)
	else:
		collision_layer = GamePhysics.get_building_layer()
	
	_team_memory = ComponentFinder.get_component(self, "TeamMemory")
	if _team_memory:
		_team_memory.current_team = player

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
	if _team_memory:
		_team_memory.current_team = p
	set_state(state) 


func return_position() -> Vector3:
	return global_position
