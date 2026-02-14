extends ColorRect

# --- SHADER MAPPING CONFIG ---
@export var max_slant: float = 0.5 # Max angle at wind speed 10

func _process(_delta: float) -> void:
	var mat = material as ShaderMaterial
	
	# 1. MAP AMOUNT (0-10 -> 0.0-1.0)
	var rain_norm = Weather.current_rain / 10.0
	mat.set_shader_parameter("rain_amount", rain_norm)
	
	# 2. MAP SLANT (Wind)
	# Wind Direction X (-1 to 1) * Wind Speed (0-10)
	# We normalize speed so 10 = max_slant
	var speed_fraction = Weather.current_wind_speed / 10.0
	var slant = Weather.current_wind_dir.x * max_slant * speed_fraction
	
	mat.set_shader_parameter("rain_slant", slant)
	
	# 3. MAP FALL SPEED
	# Rain falls faster when it's windy/stormy
	# Base speed 1.0 + extra speed from intensity
	var speed = 1.0 + (rain_norm * 0.5) + (speed_fraction * 0.5)
	mat.set_shader_parameter("rain_speed", speed)
