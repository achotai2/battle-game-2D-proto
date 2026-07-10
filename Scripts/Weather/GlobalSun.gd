extends Node

# Signals for listeners (like the Sunlight node or UI)
signal sun_updated(ambient_color: Color, shadow_color: Color)
signal sunrise
signal sunset

# --- CONFIGURATION ---
@export_group("Time Settings")
@export var day_duration: float = 120.0 # Seconds per day
@export_range(0.0, 1.0) var time_of_day: float = 0.5 # 0.0=Midnight, 0.5=Noon
@export var pause_time: bool = true

@export_group("Sun Cycle")
@export_range(0.0, 1.0) var sunrise_time: float = 0.25 
@export_range(0.0, 1.0) var sunset_time: float = 0.75 
@export var transition_duration: float = 0.1 

# ANGLE: -90 = Left, 90 = Right
@export var sunrise_angle: float = -70.0 
@export var sunset_angle: float = 70.0

@export_group("Ambient Colors")
@export var color_night: Color = Color("#0d1229")
@export var color_sunrise: Color = Color("#ff9955")
@export var color_day: Color = Color("#ffffff")
@export var color_sunset: Color = Color("#ff7755")

@export_group("Shadow Colors")
@export var shadow_color_night: Color = Color("#ffffff")   # Invisible
@export var shadow_color_sunrise: Color = Color("#6e5885") 
@export var shadow_color_day: Color = Color("#9c9c9c")     
@export var shadow_color_sunset: Color = Color("#6e4c4c")  

@export_group("Sun Position")
@export var max_shadow_length: float = 3.0
@export var min_shadow_length: float = 0.8
@export var shadow_width: float = 1.0 # <--- ADDED BACK

# --- PUBLIC VARIABLES (Read these in your Shadow Sprite) ---
var current_sun_angle: float = 0.0
var current_shadow_length: float = 1.0
var current_shadow_color: Color = Color.WHITE

# --- INTERNAL ---
var _last_phase: int = -1 


func _ready() -> void:
	# Wait for the engine to finish the current frame.
	# This gives all other nodes time to enter the tree and connect to our signals.
	await get_tree().process_frame
	
	_update_sun_position()
	_calculate_colors()


func _process(delta: float) -> void:
	if not pause_time:
		_advance_time(delta)
		_update_sun_position()
		_calculate_colors()


func _advance_time(delta: float) -> void:
	if day_duration <= 0.0: return
	var time_speed = 1.0 / day_duration
	time_of_day += delta * time_speed
	if time_of_day >= 1.0:
		time_of_day = 0.0


func _update_sun_position() -> void:
	if time_of_day < sunrise_time or time_of_day > sunset_time:
		# NIGHT
		current_shadow_length = max_shadow_length
		current_sun_angle = sunrise_angle if time_of_day < sunrise_time else sunset_angle
	else:
		# DAY
		var day_len = sunset_time - sunrise_time
		var day_progress = (time_of_day - sunrise_time) / day_len
		
		# Angle
		current_sun_angle = lerp(sunrise_angle, sunset_angle, day_progress)
		
		# Length (Shortest at noon)
		var sun_height = sin(day_progress * PI) 
		current_shadow_length = lerp(max_shadow_length, min_shadow_length, sun_height)

	# Update Global Shaders
	RenderingServer.global_shader_parameter_set("global_shadow_direction", deg_to_rad(current_sun_angle))
	RenderingServer.global_shader_parameter_set("global_shadow_length", current_shadow_length)
	# Also set color here if you use it in shaders
	RenderingServer.global_shader_parameter_set("global_shadow_color", current_shadow_color)


func _calculate_colors() -> void:
	var target_modulate = color_night
	var target_shadow = shadow_color_night
	
	# Determine Phase for Signals
	var is_day = (time_of_day >= sunrise_time and time_of_day <= sunset_time)
	if is_day and _last_phase != 1:
		_last_phase = 1
		sunrise.emit()
	elif not is_day and _last_phase != 0:
		_last_phase = 0
		sunset.emit()

	# Interpolation Logic
	if abs(time_of_day - sunrise_time) < transition_duration:
		var t = inverse_lerp(sunrise_time - transition_duration, sunrise_time + transition_duration, time_of_day)
		target_modulate = color_night.lerp(color_day, t)
		target_shadow = shadow_color_night.lerp(shadow_color_day, t)
	elif abs(time_of_day - sunset_time) < transition_duration:
		var t = inverse_lerp(sunset_time - transition_duration, sunset_time + transition_duration, time_of_day)
		target_modulate = color_day.lerp(color_night, t)
		target_shadow = shadow_color_day.lerp(shadow_color_night, t)
	elif is_day:
		target_modulate = color_day
		target_shadow = shadow_color_day
	else:
		target_modulate = color_night
		target_shadow = shadow_color_night

	current_shadow_color = target_shadow
	sun_updated.emit(target_modulate, target_shadow)


func set_time(t: float) -> void:
	time_of_day = clamp(t, 0.0, 1.0)
	_update_sun_position()
	_calculate_colors()
