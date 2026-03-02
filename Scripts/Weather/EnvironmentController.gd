extends Node

@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var mist_wall: FogVolume
@export var outline_material: ShaderMaterial 
@export var cloud_materials: Array[ShaderMaterial]
@export var minimum_night_visibility: Color = Color(0.2, 0.2, 0.3)
@export var sun_pivot: Node3D # Drag your SunPivot node here
@export var sun_visual: Sprite3D # Drag your SunVisual Sprite3D here
## A multiplier to make the sun glow brightly using HDR
@export var sun_glow_intensity: float = 3.0
## Tints for cloud layers.
@export var layer_tints: Array[Color]


func _ready() -> void:
	Sun.environment_updated.connect(_on_environment_updated)

func _on_environment_updated(sun_color: Color, fog_color: Color, ink_color: Color, sun_rot_x: float, sun_energy: float) -> void:
	# 1. Update the Sun
	var current_rot = directional_light.rotation_degrees
	directional_light.light_color = sun_color
	directional_light.rotation_degrees = Vector3(sun_rot_x, current_rot.y, current_rot.z)
	directional_light.light_energy = sun_energy
		
	# 2. Update the World Environment (Sky Darkness)
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		env.background_energy_multiplier = max(sun_energy, 0.0) 
		env.ambient_light_energy = max(sun_energy, 0.0)
		
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

	# 5. Update ALL Moving Cloud Layers
	# This loop goes through every material you add to the array in the inspector
	for i in range(cloud_materials.size()):
		var mat = cloud_materials[i]
		if mat:
			# Default to white (no change) if we haven't set a tint for this layer
			var tint = Color.WHITE 
			if i < layer_tints.size():
				tint = layer_tints[i]
				
			# Multiply the sun/fog color by the specific layer tint!
			mat.set_shader_parameter("edge_color", sun_color * tint)
			mat.set_shader_parameter("core_color", fog_color * tint)
			
	# 6. UPDATE 2D SPRITES VIA GROUPS
	var sprite_tint = minimum_night_visibility.lerp(sun_color, sun_energy)
	
	# Ask Godot to grab every single node in the entire game that has this tag
	var all_sprites = get_tree().get_nodes_in_group("sprites")
	
	for sprite in all_sprites:
		# Double-check it's actually a Sprite3D before changing properties
		if sprite is Sprite3D or sprite is AnimatedSprite3D:
			sprite.modulate = sprite_tint

	# 7. UPDATE THE FAKE SUN VISUAL
	if sun_pivot and sun_visual:
		# Rotate the pivot to swing the sun through the sky
		sun_pivot.rotation_degrees = Vector3(sun_rot_x, current_rot.y, current_rot.z)
		
		# Multiply the color by our glow intensity to force it to bloom!
		# Because we don't use sun_energy here, it stays bright even as the ground gets dark.
		sun_visual.modulate = sun_color * sun_glow_intensity
