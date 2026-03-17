extends SceneTree

func _init():
	var defs = preload("res://Scripts/DefsScripts/BuildingDefs.gd").new()
	var frames = defs.get_frames(1, 3, 1) # HOUSE (1), BUILT (3), player 1
	print("frames: ", frames)
	print("class: ", frames.get_class() if frames else "null")
	if frames is Texture2D:
		print("is Texture2D")
	else:
		print("is NOT Texture2D")
	quit()
