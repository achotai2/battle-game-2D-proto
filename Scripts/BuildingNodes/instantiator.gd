extends Node3D
class_name Instantiator

@export var unit_scene: PackedScene
@export var default_role: UnitRoles.UnitType = UnitRoles.UnitType.PEASANT

# --- POSITIONS & TARGETS ---
@export var spawn_point: Marker3D 
@export var rally_point: Node3D
@export var rally_to_castle: bool = true

# --- SPAWN TIMING ---
@export var spawn_delay: float = 60.0 
var _spawn_timer: Timer

@onready var building: BuildingBase = ComponentFinder.get_base(self)


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = spawn_delay
	_spawn_timer.one_shot = false 
	
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	
	_spawn_timer.start()


func spawn_unit() -> void:
	if not unit_scene:
		push_error("Instantiator: No unit scene assigned!")
		return
		
	print("Instantiator: Starting unit production. Ready in ", spawn_delay, " seconds.")
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	var new_unit = unit_scene.instantiate() as AgentBase
	
	if not new_unit:
		push_error("Instantiator: Assigned scene does not inherit from AgentBase!")
		return

	# --- 1. PERFECT PRE-CONFIG ---
	new_unit.player = building.player
	new_unit.current_role = default_role
	
	var is_peasant = (default_role == UnitRoles.UnitType.PEASANT)
	new_unit.collision_layer = GamePhysics.get_minion_layer(building.player, is_peasant)

	# --- 2. POSITION ---
	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# --- 3. WAKE IT UP ---
	get_tree().current_scene.add_child(new_unit)

	# --- 4. INHERIT CASTLE ---
	var my_castle = building.return_castle()
	if is_instance_valid(my_castle):
		new_unit.set_castle(my_castle)
		
	# --- 5. SMART RALLY POINT ---
	# Determine the final target: Override with Castle if the toggle is true!
	var final_target: Node3D = rally_point
	
	if rally_to_castle and is_instance_valid(my_castle):
		final_target = my_castle
		
	if is_instance_valid(final_target):
		new_unit.assign_target(final_target)
		
	print("Instantiator: Spawned a ", new_unit.name, " for Player ", building.player)
