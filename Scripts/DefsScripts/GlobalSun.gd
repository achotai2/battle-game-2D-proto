extends Node

signal sunrise
signal sunset

# --- CONFIGURATION ---
@export_group("Time Settings")
@export var day_duration: float = 20.0 # Seconds per day
@export_range(0.0, 1.0) var time_of_day: float = 0.3 # 0.0=Midnight, 0.5=Noon
@export var pause_time: bool = false

@export_group("Sun Cycle")
@export_range(0.0, 1.0) var sunrise_time: float = 0.25 # 6:00 AM
@export_range(0.0, 1.0) var sunset_time: float = 0.75  # 6:00 PM
@export var transition_duration: float = 0.1 # How long the sunrise/sunset lasts (0.1 = 10% of day)

# ANGLE: -90 = Left, 90 = Right
@export var sunrise_angle: float = -90.0 
@export var sunset_angle: float = 90.0

@export_group("Ambient Colors (CanvasModulate)")
@export var color_night: Color = Color("#0d1229")   # Deep Blue
@export var color_sunrise: Color = Color("#ff9955") # Orange/Peach
@export var color_day: Color = Color("#ffffff")     # White
@export var color_sunset: Color = Color("#ff7755")  # Red/Purple

@export_group("Shadow Colors (Multiply Mode)")
# REMEMBER: White = Invisible Shadow. Dark Grey = Strong Shadow.
@export var shadow_color_night: Color = Color("#ffffff")   # Invisible
@export var shadow_color_sunrise: Color = Color("#6e5885") # Long Purple Shadows
@export var shadow_color_day: Color = Color("#9c9c9c")     # Sharp Grey Shadows
@export var shadow_color_sunset: Color = Color("#6e4c4c")  # Long Reddish Shadows

@export_group("Sun Position")
@export var max_shadow_length: float = 3.0
@export var min_shadow_length: float = 0.8
@export var shadow_width: float = 1.0

# --- PUBLIC VARIABLES ---
var current_sun_angle: float = 0.0
var current_shadow_length: float = 1.0

# --- INTERNAL ---
var time_speed: float = 0.0

func _ready():
	if day_duration > 0:
		time_speed = 1.0 / day_duration

func _process(delta):
	if not pause_time:
		_advance_time(delta)
	
	_update_sun_position()
	_update_colors()

func _advance_time(delta):
	time_of_day += delta * time_speed
	if time_of_day >= 1.0:
		time_of_day = 0.0

func _update_sun_position():
	# 1. NIGHT CHECK
	if time_of_day < sunrise_time or time_of_day > sunset_time:
		current_sun_angle = sunrise_angle if time_of_day < sunrise_time else sunset_angle
		current_shadow_length = max_shadow_length
		# Update shader globals even at night to prevent glitches
		RenderingServer.global_shader_parameter_set("global_shadow_direction", current_sun_angle)
		RenderingServer.global_shader_parameter_set("global_shadow_length", current_shadow_length)
		return
		
	# 2. DAY PROGRESS
	var day_progress = inverse_lerp(sunrise_time, sunset_time, time_of_day)
	
	# 3. ANGLE & LENGTH
	current_sun_angle = lerp(sunrise_angle, sunset_angle, day_progress)
	
	var sun_height = sin(day_progress * PI) 
	current_shadow_length = lerp(max_shadow_length, min_shadow_length, sun_height)
	
	RenderingServer.global_shader_parameter_set("global_shadow_direction", current_sun_angle)
	RenderingServer.global_shader_parameter_set("global_shadow_length", current_shadow_length)

func _update_colors():
	var target_modulate = color_night
	var target_shadow = shadow_color_night
	
	# We define the "duration" of the transition
	var half_trans = transition_duration / 2.0
	
	# --- PHASE LOGIC ---
	
	# 1. PRE-SUNRISE (Night -> Sunrise)
	if time_of_day >= (sunrise_time - transition_duration) and time_of_day < sunrise_time:
		var t = inverse_lerp(sunrise_time - transition_duration, sunrise_time, time_of_day)
		target_modulate = color_night.lerp(color_sunrise, t)
		target_shadow = shadow_color_night.lerp(shadow_color_sunrise, t)

	# 2. POST-SUNRISE (Sunrise -> Day)
	elif time_of_day >= sunrise_time and time_of_day < (sunrise_time + transition_duration):
		var t = inverse_lerp(sunrise_time, sunrise_time + transition_duration, time_of_day)
		target_modulate = color_sunrise.lerp(color_day, t)
		target_shadow = shadow_color_sunrise.lerp(shadow_color_day, t)
		sunrise.emit()

	# 3. DAYTIME (Solid Day)
	elif time_of_day >= (sunrise_time + transition_duration) and time_of_day < (sunset_time - transition_duration):
		target_modulate = color_day
		target_shadow = shadow_color_day

	# 4. PRE-SUNSET (Day -> Sunset)
	elif time_of_day >= (sunset_time - transition_duration) and time_of_day < sunset_time:
		var t = inverse_lerp(sunset_time - transition_duration, sunset_time, time_of_day)
		target_modulate = color_day.lerp(color_sunset, t)
		target_shadow = shadow_color_day.lerp(shadow_color_sunset, t)

	# 5. POST-SUNSET (Sunset -> Night)
	elif time_of_day >= sunset_time and time_of_day < (sunset_time + transition_duration):
		var t = inverse_lerp(sunset_time, sunset_time + transition_duration, time_of_day)
		target_modulate = color_sunset.lerp(color_night, t)
		target_shadow = shadow_color_sunset.lerp(shadow_color_night, t)
		sunset.emit()

	# 6. NIGHT (Solid Night)
	else:
		target_modulate = color_night
		target_shadow = shadow_color_night

	# --- APPLY ---
	RenderingServer.global_shader_parameter_set("global_shadow_color", target_shadow)
	
	var canvas_mod = get_tree().current_scene.find_child("Sunlight", true, false)
	if canvas_mod:
		canvas_mod.color = target_modulate
	else:
		print_debug("Did not find Sunlight canvas modulate in main scene.")
