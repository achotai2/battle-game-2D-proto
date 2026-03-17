extends SceneTree

func _init():
    var house_scene = load("res://Scenes/Buildings/house.tscn")
    var house = house_scene.instantiate()
    var root = Node3D.new()
    root.add_child(house)

    var visuals = house.get_node("BuildingVisuals")
    print("visuals.visual: ", visuals.visual)
    print("house.state: ", house.state)

    house.set_state(3) # BUILT

    var sprite = house.get_node("Sprites/Sprite2D")
    print("sprite.texture: ", sprite.texture)
    print("sprite.texture path: ", sprite.texture.resource_path if sprite.texture else "null")

    quit()
