extends Instantiator
class_name NightInstantiator

@export var max_spawn: int = 10

var _spawned: int = 0


func _ready() -> void:
	# This runs the base class _ready(), which creates and starts the _tick_timer
	super._ready()

	_spawned = 0
	
	# Stop the base class's new organic timer! Only spawn at night!
	_tick_timer.stop() 

	# GlobalSun is an Autoload (Sun)
	if Sun:
		Sun.night.connect(_on_night)
		Sun.sunrise.connect(_on_sunrise)

		# If it's already night when built, start spawning
		if Sun.time_of_day > Sun.sunset_time or Sun.time_of_day < Sun.sunrise_time:
			_on_night()


func _on_night() -> void:
	if _spawned < max_spawn:
		print("NightInstantiator: Night has fallen. Spawning begins.")
		_tick_timer.start()


func _on_sunrise() -> void:
	print("NightInstantiator: Sun is rising. Spawning stops.")
	_tick_timer.stop()
	_spawned = 0
	
	# Reset the base class's organic spawn math so it's fresh for tomorrow night!
	_reset_cycle() 


# --- OVERRIDE THE BASE CLASS SPAWN FUNCTION ---
func _execute_spawn() -> void:
	# Double check the cap just in case
	if _spawned >= max_spawn:
		_tick_timer.stop()
		return
	
	var new_unit = unit_scene.instantiate() as AgentBase

	if not new_unit:
		push_error("NightInstantiator: Assigned scene does not inherit from AgentBase!")
		return

	# --- 1. PERFECT PRE-CONFIG (Night Edition) ---
	# Goblins ALWAYS belong to Player 0 (Neutral/Enemy)
	new_unit.player = 0
	new_unit.current_role = default_role
	
	# Lock in the Neutral physics layer before they wake up!
	var is_non_attackable = not UnitRoles.get_role_groups(default_role).has(&"Attackable")
	new_unit.collision_layer = GamePhysics.get_minion_layer(0, is_non_attackable)

	# --- 2. WAKE IT UP (CRITICAL PHYSICS FIX) ---
	# Add to tree BEFORE setting global_position
	get_tree().current_scene.add_child(new_unit)

	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# --- NO CASTLE REGISTRATION ---
	# (Goblins remain wild and don't pay taxes!)

	# --- 3. SMART RALLY POINT ---
	# Use the variables inherited from the base Instantiator
	var final_target: Node3D = rally_point
	var my_castle = building.return_castle()
	
	if rally_to_castle and is_instance_valid(my_castle):
		final_target = my_castle
		
	if is_instance_valid(final_target):
		new_unit.assign_target(final_target) 
			
	_spawned += 1
	print("NightInstantiator: Spawned ", _spawned, "/", max_spawn, " ", new_unit.name, " for Team 0 (Wild)")
	
	# Turn off the organic timer if we hit the limit tonight
	if _spawned >= max_spawn:
		_tick_timer.stop()
		print("NightInstantiator: Max spawn reached for tonight.")
