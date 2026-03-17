extends Node
class_name BuildingVisuals

@export var visual: Node

func update_visuals(state: int, player: int) -> void:
	if not visual:
		return

	# Strictly grab the parent to avoid ComponentFinder failing on static buildings
	var boss = ComponentFinder.get_base(self)
	if not boss:
		push_error("BuildingVisuals must be a child of BuildingBase!")
		return

	# Fetch the SpriteFrames resource from your definitions
	var frames = BuildingDefs.get_frames(boss.building_type, state, player)
	if frames == null:
		return

	if visual is AnimatedSprite3D and frames is SpriteFrames:
		var animated = visual as AnimatedSprite3D
		animated.sprite_frames = frames
		
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
		
		# --- SAFETY CHECK & PLAY ---
		# Only play if the animation actually exists in the SpriteFrames panel!
		if animated.sprite_frames.has_animation(anim_name):
			animated.play(anim_name)
		else:
			push_warning("Animation '" + anim_name + "' missing in SpriteFrames for building type: " + str(boss.building_type))
			
	# Fallbacks for static textures
	elif visual is Sprite3D and (frames is Texture2D or frames is CompressedTexture2D):
		visual.texture = frames
		
	elif (frames is Texture2D or frames is CompressedTexture2D) and visual.has_method("set_texture"):
		visual.call("set_texture", frames)
