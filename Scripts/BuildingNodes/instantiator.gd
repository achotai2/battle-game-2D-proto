extends Node3D
class_name Instantiator

@export var unit_scene: PackedScene
@export var default_role: UnitRoles.UnitType = UnitRoles.UnitType.PEASANT
@export var spawn_point: Marker3D 

# --- NEW: Spawn Delay Settings ---
@export var spawn_delay: float = 1.0 
var _spawn_timer: Timer

@onready var building: BuildingBase = ComponentFinder.get_base(self)


func _ready() -> void:
	# Dynamically generate the timer node
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = spawn_delay
	_spawn_timer.one_shot = false # Ensures it only spawns one unit per trigger
	
	# Wire up the timeout signal to our actual spawn function
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# Add it to the Instantiator node
	add_child(_spawn_timer)

	_spawn_timer.start()


func spawn_unit() -> void:
	if not unit_scene:
		push_error("Instantiator: No unit scene assigned!")
		return
		
	# Start the countdown when the building triggers it
	print("Instantiator: Starting unit production. Ready in ", spawn_delay, " seconds.")
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	# 1. Create the new unit
	var new_unit = unit_scene.instantiate() as AgentBase
	
	if not new_unit:
		push_error("Instantiator: Assigned scene does not inherit from AgentBase!")
		return

	# 2. Add to the main game world
	get_tree().current_scene.add_child(new_unit)

	# 3. Position the unit
	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# 4. Sync the Team and Role
	new_unit.apply_role(default_role, building.player)

	# 5. Inherit the Castle
	var my_castle = building.return_castle()
	if is_instance_valid(my_castle):
		new_unit.set_castle(my_castle)
		
	print("Instantiator: Spawned a ", new_unit.name, " for Player ", building.player)
