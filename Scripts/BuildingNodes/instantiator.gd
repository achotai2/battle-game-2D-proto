extends Node3D
class_name Instantiator

@export var unit_scene: PackedScene
@export var default_role: UnitRoles.UnitType = UnitRoles.UnitType.PEASANT
@export var spawn_point: Marker3D 

# --- NEW: Spawn Delay Settings ---
@export var spawn_delay: float = 60.0 
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
	# 1. Create the new unit in memory
	var new_unit = unit_scene.instantiate() as AgentBase
	
	if not new_unit:
		push_error("Instantiator: Assigned scene does not inherit from AgentBase!")
		return

	# 2. CONFIGURE BEFORE ADDING TO SCENE
	# Tell the unit who it belongs to so its _ready() function uses the right team!
	new_unit.player = building.player
	
	# Set position before adding to the scene to prevent 1-frame teleports
	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# 3. NOW add it to the main game world
	# (This instantly triggers new_unit._ready(), which will now use the correct player team)
	get_tree().current_scene.add_child(new_unit)

	# 4. Sync the Role (Team is already handled by _ready now)
	# We still call this in case default_role is different from the scene's base role
	new_unit.apply_role(default_role, building.player)

	# 5. Inherit the Castle
	var my_castle = building.return_castle()
	if is_instance_valid(my_castle):
		new_unit.set_castle(my_castle)
		
	print("Instantiator: Spawned a ", new_unit.name, " for Player ", building.player)
