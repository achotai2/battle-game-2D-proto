extends Instantiator
class_name NightInstantiator

@export var max_spawn: int = 10

var _spawned: int 


func _ready() -> void:
	super._ready()

	_spawned = 0
	
	_spawn_timer.stop() # Only spawn at night!

	# GlobalSun is an Autoload (Sun)
	if Sun:
		Sun.night.connect(_on_night)
		Sun.sunrise.connect(_on_sunrise)

		# If it's already night when built, start spawning
		if Sun.time_of_day > Sun.sunset_time or Sun.time_of_day < Sun.sunrise_time:
			_on_night()


func _on_night() -> void:
	print("NightInstantiator: Night has fallen. Spawning begins.")
	_spawn_timer.start()


func _on_sunrise() -> void:
	print("NightInstantiator: Sun is rising. Spawning stops.")
	_spawn_timer.stop()
	_spawned = 0


func _on_spawn_timer_timeout() -> void:
	if _spawned >= max_spawn:
		_spawn_timer.stop()
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
	var is_peasant = (default_role == UnitRoles.UnitType.PEASANT)
	new_unit.collision_layer = GamePhysics.get_minion_layer(0, is_peasant)

	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# --- 2. WAKE IT UP ---
	# _ready() runs, permanently cementing them as Player 0 enemies
	get_tree().current_scene.add_child(new_unit)

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
	print("NightInstantiator: Have spawned ", _spawned, " ", new_unit.name, " for Team 0 (Wild)")
