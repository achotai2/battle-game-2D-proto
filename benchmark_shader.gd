extends SceneTree

func _init():
    var start = Time.get_ticks_usec()
    for i in range(100000):
        # We need a sprite with a material to actually benchmark the call,
        pass
    print("Empty benchmark: ", Time.get_ticks_usec() - start, "us")
    quit()
