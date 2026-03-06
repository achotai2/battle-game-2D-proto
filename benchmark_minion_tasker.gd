extends SceneTree

func _init():
    print("Starting benchmark...")

    var agent = Node3D.new()
    agent.global_position = Vector3(0, 0, 0)

    var tasker = preload("res://Scripts/MemoryNodes/minion_tasker.gd").new()
    tasker.agent = agent

    var sites = []
    # Create 1000 known jobs
    for i in range(1000):
        var site = preload("res://Scripts/BuildingNodes/worksite.gd").new()
        site.global_position = Vector3(randf() * 100, 0, randf() * 100)
        # Mock needs_work() to return true
        site.set_script(preload("res://Scripts/BuildingNodes/worksite.gd"))
        # we will use an instance method override if possible, otherwise rely on default
        sites.append(site)
        tasker._known_jobs.append(site)

    var start = Time.get_ticks_usec()
    var iterations = 100
    for i in range(iterations):
        tasker.get_known_jobs_sorted_by_distance()
    var end = Time.get_ticks_usec()

    print("Time taken for ", iterations, " iterations: ", (end - start) / 1000.0, " ms")

    quit()
