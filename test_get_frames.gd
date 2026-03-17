extends SceneTree

func _init():
	var defs = preload("res://Scripts/DefsScripts/BuildingDefs.gd").new()
	var state: int = 3 # BUILT
	var player: int = 1
	var building_type: int = 1 # HOUSE

	var frames = defs.get_frames(building_type, state, player)
	print("frames: ", frames)
	quit()
