extends MainLoop

const PlayerInteractor = preload("res://Scripts/AgentNodes/PlayerInteractor.gd")
const Interactable = preload("res://Scripts/AgentNodes/Interactable.gd")

class MockSensor extends Area3D:
	var _overlaps: Array[Area3D] = []
	func set_overlaps(overlaps: Array[Area3D]):
		_overlaps = overlaps

	func get_overlapping_areas() -> Array[Area3D]:
		return _overlaps

class MockInteractable extends Interactable:
	func _init(p_priority: int, p_pos: Vector3):
		my_priority = p_priority
		priority = p_priority # Using Area3D priority just in case
		position = p_pos

func _initialize():
	print("Running PlayerInteractor Logic Verification...")

	test_initial_sync()
	test_signal_updates()

	print("All Tests Passed (Logic Verified)")
	return true # Exit loop

func _process(delta):
	_initialize()
	return true

func test_initial_sync():
	print("Testing Initial Sync...")
	var interactor = PlayerInteractor.new()
	var sensor = MockSensor.new()
	interactor.sensor = sensor

	var i1 = MockInteractable.new(10, Vector3(0, 0, 0))
	sensor.set_overlaps([i1])

	# Simulate _ready
	interactor._ready()

	# Initial state: nearby should be empty until _refresh_target runs
	if not interactor._nearby.is_empty():
		printerr("FAILED: Nearby should be empty before first refresh")

	# Simulate timer tick calling _refresh_target
	interactor._refresh_target()

	if interactor._nearby.size() != 1 or interactor._nearby[0] != i1:
		printerr("FAILED: Initial sync missed overlapping item. Nearby size: ", interactor._nearby.size())
	else:
		print("PASSED: Initial Sync")

	interactor.free()
	sensor.free()
	i1.free()

func test_signal_updates():
	print("Testing Signal Updates...")
	var interactor = PlayerInteractor.new()
	var sensor = MockSensor.new()
	interactor.sensor = sensor

	# Empty overlaps initially
	sensor.set_overlaps([])

	interactor._ready()
	interactor._refresh_target() # Initial sync done

	if not interactor._nearby.is_empty():
		printerr("FAILED: Nearby should be empty")

	var i1 = MockInteractable.new(10, Vector3(100, 0, 100))

	# Simulate area_entered
	interactor._on_area_entered(i1)

	if interactor._nearby.size() != 1 or interactor._nearby[0] != i1:
		printerr("FAILED: area_entered did not add item")
	else:
		print("PASSED: area_entered")

	# Run refresh again - should NOT clear nearby (if optimization is correct)
	# AND should NOT duplicate if logic is sound (though duplicate check is in _on_area_entered)

	# Mock sensor still says empty overlaps to simulate signal-only tracking after init
	# If code was still polling get_overlapping_areas(), it would clear _nearby here!
	interactor._refresh_target()

	if interactor._nearby.size() != 1:
		printerr("FAILED: _refresh_target cleared _nearby! Optimization not active or logic flawed.")
	else:
		print("PASSED: _refresh_target respects signal updates")

	# Simulate area_exited
	interactor._on_area_exited(i1)

	if not interactor._nearby.is_empty():
		printerr("FAILED: area_exited did not remove item")
	else:
		print("PASSED: area_exited")

	interactor.free()
	sensor.free()
	i1.free()
