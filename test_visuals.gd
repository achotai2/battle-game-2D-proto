extends SceneTree

func _init():
	var house = preload("res://Scenes/Buildings/house.tscn").instantiate()
	var visuals = house.get_node("BuildingVisuals")
	print("visuals node: ", visuals)
	print("visuals.visual: ", visuals.visual)
	var frames = preload("res://Scripts/DefsScripts/BuildingDefs.gd").new().get_frames(1, 3, 1) # BARRACKS, BUILT, player 1
	print("frames: ", frames)
	print("is Texture2D: ", frames is Texture2D)
	print("visual is Sprite3D: ", visuals.visual is Sprite3D)
	quit()
