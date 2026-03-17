extends SceneTree

func _init():
	print("--- test start ---")
	var tex = preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Blue.png")
	print("tex is Texture2D: ", tex is Texture2D)
	print("tex class: ", tex.get_class())

	quit()
