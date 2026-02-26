extends Node

@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var mist_wall: FogVolume
@export var outline_material: ShaderMaterial 

func _ready() -> void:
	Sun.environment_updated.connect(_on_environment_updated)

func _on_environment_updated(sun_color: Color, fog_color: Color, ink_color: Color, sun_rot_x: float, sun_energy: float) -> void:
	
	# 1. Update the Sun
	if directional_light:
		directional_light.light_color = sun_color
		var current_rot = directional_light.rotation_degrees
		directional_light.rotation_degrees = Vector3(sun_rot_x, current_rot.y, current_rot.z)
		directional_light.light_energy = sun_energy
		
	# 2. Update the World Environment (Sky Darkness)
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		env.background_energy_multiplier = max(sun_energy, 0.05) 
		env.ambient_light_energy = max(sun_energy, 0.05)
		
	# 3. UPDATE THE FOG VOLUME NODE
	if mist_wall and mist_wall.material:
		# We cast it to a FogMaterial so Godot knows what properties it has
		var fog_mat = mist_wall.material as FogMaterial
		if fog_mat:
			fog_mat.albedo = fog_color
			# Inject a tiny bit of self-glow so the color cuts through the dark!
			fog_mat.emission = fog_color * max(sun_energy, 0.15)
		
	# 4. Update the Outline Shader
	if outline_material:
		outline_material.set_shader_parameter("ink_color", ink_color)
