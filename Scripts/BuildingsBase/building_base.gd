extends StaticBody3D
class_name BuildingBase

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

var _team_memory: Node = null


func _ready() -> void:
	collision_layer = GamePhysics.get_building_layer()
	
	_team_memory = ComponentFinder.get_component(self, "TeamMemory")
	if _team_memory:
		_team_memory.current_team = player

	# 1. Wire up the Construction Pipeline
	if construct_interactable:
		construct_interactable.interaction_finished.connect(_on_construct_clicked)
	if construct_site:
		construct_site.work_completed.connect(_on_construct_finished)

	# 2. Boot up the building
	set_state(state)


# --- STATE MACHINE (THE SWITCHBOARD) ---

func set_state(new_state: BuildingDefs.BuildingState) -> void:
	state = new_state

	_disable_all_systems()

	match state:
		BuildingDefs.BuildingState.DESTROYED:
			if construct_interactable:
				# Tell the interactable what icon to show and how much gold it costs
				var cost = BuildingDefs.get_construction_cost(building_type)
				var icon = BuildingDefs.get_interact_mode(building_type, state)
				construct_interactable.update_interaction_state(icon, cost)
				construct_interactable.set_enabled(true)
				
			visuals.update_visuals(state, player)

		BuildingDefs.BuildingState.CONSTRUCTING:
			if construct_site:
				construct_site.total_work = BuildingDefs.get_construction_cost(building_type)
				construct_site.reset_progress()
				construct_site.set_enabled(true) # This auto-registers with the Job Board!
				construct_site.refresh_registration()
				
			visuals.update_visuals(state, player)

		BuildingDefs.BuildingState.BUILT:
			if spawn_interactable:
				# Setup the production interactable
				var config = BuildingDefs.get_spawn_config(building_type)
				var unit_type = config.get("unit_type", 0)
				var cost = BuildingDefs.get_unit_train_cost(unit_type)
				var icon = BuildingDefs.get_interact_mode(building_type, state)
				spawn_interactable.update_interaction_state(icon, cost)
				spawn_interactable.set_enabled(true)
				
			visuals.update_visuals(state, player)


func _disable_all_systems() -> void:
	if construct_interactable: construct_interactable.set_enabled(false)
	if spawn_interactable: spawn_interactable.set_enabled(false)
	if construct_site: construct_site.set_enabled(false)


# --- SIGNAL HANDLERS ---

func _on_construct_clicked(interactor: AgentBase) -> void:
	# The player clicked the ruins! Time to start building.
	set_state(BuildingDefs.BuildingState.CONSTRUCTING)


func _on_construct_finished(site: WorkSite, worker: AgentBase) -> void:
	# The workers finished hammering! The building is now active.
	set_state(BuildingDefs.BuildingState.BUILT)


func _on_destroyed() -> void:
	# Called if the building health reaches 0
	# You might also want to tell the ProductionQueue to clear its arrays here!
	set_state(BuildingDefs.BuildingState.DESTROYED)


# --- PUBLIC GETTERS ---

func set_player(p: int) -> void:
	player = p
	if _team_memory:
		_team_memory.current_team = p
	set_state(state) # Refresh visuals

func return_castle() -> Castle:
	return castle

func return_position() -> Vector3:
	return global_position
