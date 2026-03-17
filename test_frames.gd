extends SceneTree

func _init():
	var defs = preload("res://Scripts/DefsScripts/BuildingDefs.gd").new()
	var frames = defs.get_frames(1, 3, 1) # BARRACKS, BUILT, player 1
	print("frames: ", frames)
	print("frames type: ", type_string(typeof(frames)))
	print("has_method set_texture: ", preload("res://Scenes/Buildings/house.tscn").instantiate().get_node("Sprites/Sprite2D").has_method("set_texture"))
	quit()
