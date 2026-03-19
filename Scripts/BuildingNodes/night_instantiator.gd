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
	
	# Override base behavior to change player assignment
	var new_unit = unit_scene.instantiate() as AgentBase

	if not new_unit:
		push_error("NightInstantiator: Assigned scene does not inherit from AgentBase!")
		return

	get_tree().current_scene.add_child(new_unit)

	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# Goblins always belong to team 0 (Neutral/Enemy)
	new_unit.apply_role(default_role, 0)

	# Inherit the Castle
	var my_castle = building.return_castle()
	if is_instance_valid(my_castle):
		new_unit.set_castle(my_castle)

	_spawned += 1
	print("NightInstantiator: Have spawned ", _spawned, " ", new_unit.name, " for Team 0 (Night Only)")
