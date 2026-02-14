extends TextureRect

# --- SHADER MAPPING CONFIG ---
# Clouds 0 -> Cutoff 1.1 (Invisible)
# Clouds 10 -> Cutoff 0.3 (Dense)
@export var min_cutoff: float = 1.1 
@export var max_cutoff: float = 0.3 

# Clouds 0 -> Light Grey Shadow
# Clouds 10 -> Dark Black Shadow
@export var color_light: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var color_dark: Color = Color(0.4, 0.4, 0.4, 1.0)

# Multiplier for wind speed
@export var speed_factor: float = 0.02

func _process(_delta: float) -> void:
	# Read from Global Weather directly every frame for smooth interpolation
	var intensity_norm = Weather.current_clouds / 10.0 # 0.0 to 1.0
	var mat = material as ShaderMaterial
	
	# 1. MAP CUTOFF (Density)
	# Use remap or lerp logic
	# 0.0 -> min_cutoff, 1.0 -> max_cutoff
	var target_cutoff = lerp(min_cutoff, max_cutoff, intensity_norm)
	mat.set_shader_parameter("cloud_cutoff", target_cutoff)
	
	# 2. MAP COLOR (Darkness)
	var target_color = color_light.lerp(color_dark, intensity_norm)
	mat.set_shader_parameter("shadow_color", target_color)
	
	# 3. MAP WIND
	# Direction
	mat.set_shader_parameter("cloud_direction", Weather.current_wind_dir)
	# Speed (0-10 scale -> Shader scale)
	mat.set_shader_parameter("speed_scale", Weather.current_wind_speed * speed_factor)
	
	# 4. Optional: Frequency (Detail)
	# Storms usually have larger, blobbier clouds (low freq)
	if texture is NoiseTexture2D and texture.noise is FastNoiseLite:
		var target_freq = lerp(0.02, 0.005, intensity_norm)
		# Only update noise if changed significantly (expensive operation)
		if abs(texture.noise.frequency - target_freq) > 0.002:
			texture.noise.frequency = target_freq
