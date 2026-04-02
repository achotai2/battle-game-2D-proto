extends Node3D
class_name Instantiator

@export var unit_scene: PackedScene
@export var default_role: UnitRoles.UnitType = UnitRoles.UnitType.PEASANT

# --- POSITIONS & TARGETS ---
@export var spawn_point: Marker3D 
@export var rally_point: Node3D
@export var rally_to_castle: bool = true

# --- ORGANIC SPAWN TIMING ---
@export var spawn_delay: float = 60.0 
@export var check_interval: float = 1.0 ## How often we roll the dice (in seconds)
@export var curve_steepness: float = 3.0 ## Higher = less likely early on, spikes at the very end

var _tick_timer: Timer
var _elapsed_time: float = 0.0
var _has_spawned_this_cycle: bool = false

@onready var building: BuildingBase = ComponentFinder.get_base(self)


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.name = "TickTimer"
	_tick_timer.wait_time = check_interval
	_tick_timer.one_shot = false 
	
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	
	_tick_timer.start()


func _on_tick() -> void:
	_elapsed_time += check_interval

	# 1. If we already popped our 1 unit, we are just waiting for the 60s cycle to finish.
	if _has_spawned_this_cycle:
		if _elapsed_time >= spawn_delay:
			_reset_cycle()
		return

	# 2. The Absolute Limit: If we hit 60 seconds, force the spawn!
	if _elapsed_time >= spawn_delay:
		_execute_spawn()
		_has_spawned_this_cycle = true
		return

	# 3. Roll the dice!
	var time_ratio = _elapsed_time / spawn_delay
	
	# Using pow() creates our curve. 
	# At 30s (0.5 ratio) with a steepness of 3, the chance is only 12.5% per tick.
	# At 55s (0.91 ratio), the chance jumps to 77% per tick!
	var spawn_chance = pow(time_ratio, curve_steepness) 

	if randf() <= spawn_chance:
		_execute_spawn()
		_has_spawned_this_cycle = true


func _reset_cycle() -> void:
	_elapsed_time = 0.0
	_has_spawned_this_cycle = false
	print("Instantiator: Cycle reset. Starting new spawn window.")


func _execute_spawn() -> void:
	if not unit_scene:
		push_error("Instantiator: No unit scene assigned!")
		return
		
	var new_unit = unit_scene.instantiate() as AgentBase
	
	if not new_unit:
		push_error("Instantiator: Assigned scene does not inherit from AgentBase!")
		return

	# --- 1. PERFECT PRE-CONFIG ---
	new_unit.player = building.player
	new_unit.current_role = default_role
	
	var is_non_attackable = not UnitRoles.get_role_groups(default_role).has(&"Attackable")
	new_unit.collision_layer = GamePhysics.get_minion_layer(building.player, is_non_attackable)

	# --- 2. WAKE IT UP (Before setting position!) ---
	get_tree().current_scene.add_child(new_unit)

	# --- 3. POSITION ---
	if spawn_point:
		new_unit.global_position = spawn_point.global_position
	else:
		new_unit.global_position = self.global_position

	# --- 4. INHERIT CASTLE ---
	var my_castle = building.return_castle()
	if is_instance_valid(my_castle):
		new_unit.set_castle(my_castle)
		
	# --- 5. SMART RALLY POINT ---
	var final_target: Node3D = rally_point
	if rally_to_castle and is_instance_valid(my_castle):
		final_target = my_castle
		
	if is_instance_valid(final_target):
		new_unit.assign_target(final_target)
		
	print("Instantiator: Organically spawned a ", new_unit.name, " at ", _elapsed_time, " seconds!")
