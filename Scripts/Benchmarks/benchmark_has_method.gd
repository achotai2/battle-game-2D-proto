extends SceneTree

# Benchmark to compare has_method + call vs direct method call
# To run: godot -s Scripts/Benchmarks/benchmark_has_method.gd --headless

class TestObj:
    func method(arg):
        return arg

func _init():
    var obj = TestObj.new()
    var iterations = 1000000

    print("Running benchmark with ", iterations, " iterations...")

    # Measure direct call
    var t_start = Time.get_ticks_usec()
    for i in range(iterations):
        var res = obj.method(i)
    var t_direct = Time.get_ticks_usec() - t_start
    print("Direct call time:         ", t_direct, " us")

    # Measure has_method + direct call
    t_start = Time.get_ticks_usec()
    for i in range(iterations):
        if obj.has_method("method"):
            var res = obj.method(i)
    var t_has_method = Time.get_ticks_usec() - t_start
    print("has_method + direct call: ", t_has_method, " us")

    if t_direct > 0:
        var ratio = float(t_has_method) / float(t_direct)
        print("Ratio (has_method / direct): ", ratio)
        print("Direct call is ", ratio, "x faster")

    quit()
