extends Node
class_name BuildingVisuals

@export var visual: Node
@export var shadowVisual: Node

func update_visuals(state: BuildingDefs.BuildingState, player: int) -> void:
	if not visual:
		return

	var boss = ComponentFinder.get_base(self)
	var frames = BuildingDefs.get_frames(boss.building_type, state, player)
	if frames == null:
		return

	if visual is AnimatedSprite3D and frames is SpriteFrames:
		var animated = visual as AnimatedSprite3D
		animated.sprite_frames = frames
		if animated.sprite_frames.get_animation_names().size() > 0:
			animated.animation = animated.sprite_frames.get_animation_names()[0]
		animated.play()
		
	elif visual is Sprite3D and frames is Texture2D:
		visual.texture = frames
		if shadowVisual: shadowVisual.texture = frames
		
	elif frames is Texture2D and visual.has_method("set_texture"):
		visual.call("set_texture", frames)
		if shadowVisual: shadowVisual.call("set_texture", frames)
