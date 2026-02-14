extends Node

enum WeatherState { CLEAR, OVERCAST, LIGHT_RAIN, STORM }

# --- WEATHER CONTROLS ---
@export_category("Weather Control")
@export var current_state: WeatherState = WeatherState.CLEAR:
	set(value):
		current_state = value
		_apply_weather()

@export var wind_direction: Vector2 = Vector2(1, 0):
	set(value):
		wind_direction = value.normalized()
		_apply_weather()

@export_range(0.0, 20.0, 0.5) var transition_duration: float = 5.0

# --- SUN CONTROLS ---
@export_category("Sun Control")

# Drag this slider in the Remote Inspector to scrub time!
@export_range(0.0, 1.0) var set_time_of_day: float = 0.3:
	set(value):
		set_time_of_day = value
		if has_node("/root/Sun"):
			Sun.set_time(value)

@export var pause_day_cycle: bool = false:
	set(value):
		pause_day_cycle = value
		if has_node("/root/Sun"):
			Sun.pause_time = value

func _ready() -> void:
	pass

func _apply_weather() -> void:
	if not is_inside_tree() or not has_node("/root/Weather"): return
	
	Weather.set_transition_duration(transition_duration)
	
	var target_dict = {}
	match current_state:
		WeatherState.CLEAR: target_dict = Weather.STATE_CLEAR
		WeatherState.OVERCAST: target_dict = Weather.STATE_OVERCAST
		WeatherState.LIGHT_RAIN: target_dict = Weather.STATE_LIGHT_RAIN
		WeatherState.STORM: target_dict = Weather.STATE_STORM
	
	Weather.set_weather_state(target_dict, wind_direction, false)
	print("WeatherControl: Switching to ", WeatherState.keys()[current_state])
