extends SceneTree

# Simple benchmark to compare direct method call vs call()
# To run: godot -s Scripts/Benchmarks/benchmark_call.gd --headless

class TestObj:
    func method(arg):
        pass

func _init():
    var obj = TestObj.new()
    var iterations = 1000000

    print("Running benchmark with ", iterations, " iterations...")

    # Measure direct call
    var t_start = Time.get_ticks_usec()
    for i in range(iterations):
        obj.method(i)
    var t_direct = Time.get_ticks_usec() - t_start
    print("Direct call time: ", t_direct, " us")

    # Measure call()
    t_start = Time.get_ticks_usec()
    for i in range(iterations):
        obj.call("method", i)
    var t_call = Time.get_ticks_usec() - t_start
    print("call() time:      ", t_call, " us")

    if t_direct > 0:
        var ratio = float(t_call) / float(t_direct)
        print("Ratio (call / direct): ", ratio)
        print("Direct call is ", ratio, "x faster")

    quit()
