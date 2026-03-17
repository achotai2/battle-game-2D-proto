extends SceneTree

func _init():
    var img = load("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Blue.png")
    print("img class: ", img.get_class() if img else "null")
    print("is Texture2D: ", img is Texture2D)
    print("is CompressedTexture2D: ", img is CompressedTexture2D)
    quit()
