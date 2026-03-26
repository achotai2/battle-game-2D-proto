extends SceneTree

func _init():
    var arr = []
    for i in range(1000):
        arr.append({"site": i, "dist": randf()})

    var t1 = Time.get_ticks_usec()
    for j in range(100):
        var arr_copy = arr.duplicate()
        arr_copy.sort_custom(func(a, b): return a.dist < b.dist)
    var t2 = Time.get_ticks_usec()
    print("Sort custom: ", (t2 - t1) / 1000.0, " ms")
    quit()
