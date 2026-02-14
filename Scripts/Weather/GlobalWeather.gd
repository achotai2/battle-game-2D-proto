extends Node

# --- 1. DEFINITIONS ---
# A Weather State is just a dictionary of target values.
# Clouds: 0.0 (Clear) to 10.0 (Full Blockout)
# Rain: 0.0 (Dry) to 10.0 (Torrential)
# Wind Speed: 0.0 (Calm) to 10.0 (Hurricane)
# Wind Dir: Normalized Vector2

const STATE_CLEAR = {
	"clouds": 0.0,
	"rain": 0.0,
	"wind_speed": 1.0,
	"color_mood": Color(1.0, 1.0, 1.0) # Bright Sun
}

const STATE_OVERCAST = {
	"clouds": 7.0,
	"rain": 0.0,
	"wind_speed": 3.0,
	"color_mood": Color(0.38, 0.376, 0.455, 1.0) # Dull Grey-Blue
}

const STATE_LIGHT_RAIN = {
	"clouds": 8.0,
	"rain": 3.0,
	"wind_speed": 4.0,
	"color_mood": Color(0.457, 0.456, 0.515, 1.0)
}

const STATE_STORM = {
	"clouds": 10.0,
	"rain": 9.0,
	"wind_speed": 9.0,
	"color_mood": Color(0.203, 0.202, 0.261, 1.0) # Dark Blue-Grey
}

# --- 2. CURRENT VALUES (Read these from your shaders) ---
var current_clouds: float = 0.0
var current_rain: float = 0.0
var current_wind_speed: float = 0.0
var current_wind_dir: Vector2 = Vector2(1, 0) # Default East
var current_mood_color: Color = Color.WHITE

# --- 3. TARGETS (Internal) ---
var _target_clouds: float = 0.0
var _target_rain: float = 0.0
var _target_wind_speed: float = 0.0
var _target_wind_dir: Vector2 = Vector2(1, 0)
var _target_mood_color: Color = Color.WHITE

var _transition_speed: float = 0.5 # How fast we change states


func _ready() -> void:
	# Start Clear
	set_weather_state(STATE_CLEAR, Vector2(1, 0), true)


func _process(delta: float) -> void:
	# Smoothly Interpolate values
	var t = delta * _transition_speed
	
	# Variables with range 0-10 need to move 10x faster to match duration of 0-1 variables
	current_clouds = move_toward(current_clouds, _target_clouds, t * 10.0)
	current_rain = move_toward(current_rain, _target_rain, t * 10.0)
	current_wind_speed = move_toward(current_wind_speed, _target_wind_speed, t * 10.0)
	
	# Smoothly rotate wind direction (Slerp is better for rotation, but Lerp is fine here)
	current_wind_dir = current_wind_dir.lerp(_target_wind_dir, t).normalized()
	
	current_mood_color = current_mood_color.lerp(_target_mood_color, t)
	
	# --- LOGIC ENFORCEMENT ---
	# "No Rain without Clouds"
	# We clamp rain so it can never be higher than cloud cover.
	# As clouds fade out, rain is forced to fade out with them.
	if current_rain > current_clouds:
		current_rain = current_clouds

	# Optimization: Stop processing if targets are reached
	if _are_targets_reached():
		set_process(false)

func _are_targets_reached() -> bool:
	return is_equal_approx(current_clouds, _target_clouds) and \
		   is_equal_approx(current_rain, _target_rain) and \
		   is_equal_approx(current_wind_speed, _target_wind_speed) and \
		   current_wind_dir.distance_squared_to(_target_wind_dir) < 0.001 and \
		   current_mood_color.is_equal_approx(_target_mood_color)


# --- API ---

func set_weather_state(state_dict: Dictionary, wind_dir: Vector2 = Vector2.ZERO, instant: bool = false) -> void:
	set_process(true)

	_target_clouds = state_dict.get("clouds", 0.0)
	_target_rain = state_dict.get("rain", 0.0)
	_target_wind_speed = state_dict.get("wind_speed", 0.0)
	_target_mood_color = state_dict.get("color_mood", Color.WHITE)
	
	# If direction isn't provided, keep the old one
	if wind_dir != Vector2.ZERO:
		_target_wind_dir = wind_dir.normalized()
		
	if instant:
		current_clouds = _target_clouds
		current_rain = _target_rain
		current_wind_speed = _target_wind_speed
		current_wind_dir = _target_wind_dir
		current_mood_color = _target_mood_color

# Call this to change how fast weather transitions happen
func set_transition_duration(seconds: float) -> void:
	if seconds > 0:
		_transition_speed = 1.0 / seconds
	else:
		_transition_speed = 100.0 # Instant
