extends Node

# Signal now includes sun_energy!
signal environment_updated(sun_color: Color, fog_color: Color, ink_color: Color, sun_rot_x: float, sun_energy: float)
signal sunrise
signal sunset
signal night
signal day

@export_group("Time Settings")
@export var day_duration: float = 20.0 
@export_range(0.0, 1.0) var time_of_day: float = 0.3 
@export var pause_time: bool = false

@export_group("Sun Cycle")
@export_range(0.0, 1.0) var sunrise_time: float = 0.25 
@export_range(0.0, 1.0) var sunset_time: float = 0.75 
@export var transition_duration: float = 0.1 

# Sunrise is -180, Noon is -90, Sunset is 0. 
@export_group("Sun Angles (X Rotation)")
@export var sun_angle_sunrise: float = -180.0 
@export var sun_angle_noon: float = -90.0
@export var sun_angle_sunset: float = 0.0

@export_group("Sun Colors")
@export var sun_night: Color = Color("000000ff")
@export var sun_sunrise: Color = Color("b65a00ff")
@export var sun_day: Color = Color("#ffffff")
@export var sun_sunset: Color = Color("dc3100ff")

@export_group("Fog Colors")
@export var fog_night: Color = Color("#050814")
@export var fog_sunrise: Color = Color("#8c5e58")
@export var fog_day: Color = Color("#d6e3f2")
@export var fog_sunset: Color = Color("#8c4f4f")

@export_group("Ink Colors")
#@export var ink_night: Color = Color("#0a0a0f")
@export var ink_night: Color = Color("1b2c69ff")
@export var ink_sunrise: Color = Color("#d4a373") 
@export var ink_day: Color = Color("#1a1a24")
@export var ink_sunset: Color = Color("#d4a373") 

var current_sun_rot_x: float = 0.0
var current_sun_energy: float = 1.0
var _last_phase: int = -1 


func _process(delta: float) -> void:
	if not pause_time:
		_advance_time(delta)
		_update_sun_position()
		_calculate_environment()
		_check_phase()


func _check_phase() -> void:
	var phase: int

	if time_of_day >= sunrise_time and time_of_day <= sunset_time:
		phase = 0 # Day
	else:
		phase = 1 # Night

	if phase != _last_phase:
		_last_phase = phase
		if phase == 0:
			sunrise.emit()
			day.emit()
		elif phase == 1:
			sunset.emit()
			night.emit()


func _advance_time(delta: float) -> void:
	if day_duration <= 0.0: return
	time_of_day += delta * (1.0 / day_duration)
	if time_of_day >= 1.0: time_of_day = 0.0


func _update_sun_position() -> void:
	var day_len = sunset_time - sunrise_time
	
	if time_of_day >= sunrise_time and time_of_day <= sunset_time:
		# --- DAYTIME ARC --- (-180 to 0)
		var day_progress = (time_of_day - sunrise_time) / day_len
		if day_progress < 0.5:
			current_sun_rot_x = lerp(sun_angle_sunrise, sun_angle_noon, day_progress * 2.0)
		else:
			current_sun_rot_x = lerp(sun_angle_noon, sun_angle_sunset, (day_progress - 0.5) * 2.0)
	else:
		# --- NIGHTTIME ARC --- (0 to 180) smoothly rotating under the world
		var night_len = 1.0 - day_len
		var time_into_night = time_of_day - sunset_time if time_of_day > sunset_time else (1.0 - sunset_time) + time_of_day
		var night_progress = time_into_night / night_len
		
		current_sun_rot_x = lerp(sun_angle_sunset, 180.0, night_progress)
		if current_sun_rot_x > 180.0: current_sun_rot_x -= 360.0 # Keep angles clean


func _calculate_environment() -> void:
	var target_energy := 1.0
	
	# 1. Sunrise Transition
	if abs(time_of_day - sunrise_time) <= transition_duration:
		var t = inverse_lerp(sunrise_time - transition_duration, sunrise_time + transition_duration, time_of_day)
		target_energy = lerp(0.0, 1.0, t)
			
	# 2. Sunset Transition
	elif abs(time_of_day - sunset_time) <= transition_duration:
		var t = inverse_lerp(sunset_time - transition_duration, sunset_time + transition_duration, time_of_day)
		target_energy = lerp(1.0, 0.0, t)
			
	# 3. Broad Day vs Broad Night
	elif time_of_day > sunrise_time + transition_duration and time_of_day < sunset_time - transition_duration:
		target_energy = 1.0
	else:
		target_energy = 0.0

	current_sun_energy = target_energy

	# Get Colors
	var current_sun_color = _get_blended_color(sun_night, sun_sunrise, sun_day, sun_sunset)
	var current_fog_color = _get_blended_color(fog_night, fog_sunrise, fog_day, fog_sunset)
	var current_ink_color = _get_blended_color(ink_night, ink_sunrise, ink_day, ink_sunset)

	# Broadcast everything!
	environment_updated.emit(current_sun_color, current_fog_color, current_ink_color, current_sun_rot_x, current_sun_energy)


func _get_blended_color(night_col: Color, sunrise_col: Color, day_col: Color, sunset_col: Color) -> Color:
	if abs(time_of_day - sunrise_time) <= transition_duration:
		var t = inverse_lerp(sunrise_time - transition_duration, sunrise_time + transition_duration, time_of_day)
		return night_col.lerp(sunrise_col, t * 2.0) if t < 0.5 else sunrise_col.lerp(day_col, (t - 0.5) * 2.0)
	elif abs(time_of_day - sunset_time) <= transition_duration:
		var t = inverse_lerp(sunset_time - transition_duration, sunset_time + transition_duration, time_of_day)
		return day_col.lerp(sunset_col, t * 2.0) if t < 0.5 else sunset_col.lerp(night_col, (t - 0.5) * 2.0)
	elif time_of_day > sunrise_time + transition_duration and time_of_day < sunset_time - transition_duration:
		return day_col
	else:
		return night_col
