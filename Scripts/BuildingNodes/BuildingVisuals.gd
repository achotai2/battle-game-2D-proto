extends Node
class_name BuildingVisuals

# --- EXPORT BOTH POTENTIAL VISUAL NODES ---
@export var visual_sprite: Node3D # Assign your Sprite3D or AnimatedSprite3D here
@export var visual_mesh: MeshInstance3D # Assign your MeshInstance3D here


func update_visuals(state: int, player: int) -> void:
	var boss = ComponentFinder.get_base(self)
	if not boss:
		push_error("BuildingVisuals must be a child of BuildingBase!")
		return

	# Fetch the resource (This could now be a Texture2D, SpriteFrames, or Mesh!)
	var visual_data = BuildingDefs.get_frames(boss.building_type, state, player)
	if visual_data == null:
		return

	# --- 1. CLEAN SLATE: HIDE EVERYTHING ---
	if is_instance_valid(visual_sprite):
		visual_sprite.hide()
	if is_instance_valid(visual_mesh):
		visual_mesh.hide()

	# --- 2. STATIC 2D SPRITE (.png) ---
	if visual_data is Texture2D or visual_data is CompressedTexture2D:
		if visual_sprite is Sprite3D:
			visual_sprite.texture = visual_data
			visual_sprite.show()
		else:
			push_warning("Building Visuals: Received a Texture, but visual_sprite is not a Sprite3D!")

	# --- 3. ANIMATED 2D SPRITE (.tres) ---
	elif visual_data is SpriteFrames:
		if visual_sprite is AnimatedSprite3D:
			visual_sprite.sprite_frames = visual_data
			visual_sprite.show()
			
			# --- THE STATE MAPPING ---
			var anim_name: String = ""
			match state:
				BuildingDefs.BuildingState.DESTROYED:
					anim_name = "destroyed"
				BuildingDefs.BuildingState.CONSTRUCTING:
					anim_name = "constructing"
				BuildingDefs.BuildingState.BUILDING:
					anim_name = "building"
				BuildingDefs.BuildingState.BUILT:
					anim_name = "built"
			
			# Only play if the animation actually exists in the SpriteFrames panel!
			if visual_sprite.sprite_frames.has_animation(anim_name):
				visual_sprite.play(anim_name)
			else:
				push_warning("Animation '" + anim_name + "' missing in SpriteFrames for building type: " + str(boss.building_type))
		else:
			push_warning("Building Visuals: Received SpriteFrames, but visual_sprite is not an AnimatedSprite3D!")

	# --- 4. 3D MODEL (.obj / ArrayMesh) ---
	elif visual_data is Mesh:
		if is_instance_valid(visual_mesh):
			visual_mesh.mesh = visual_data
			visual_mesh.show()
		else:
			push_warning("Building Visuals: Received a 3D Mesh, but visual_mesh is not assigned!")
