extends Node

# A simple verification script for AgentTracking logic.
# Run this with godot --headless -s Scripts/Tests/test_tracking_logic.gd if possible,
# or review the logic to ensure the optimization works as intended.

# Mock Agent class
class MockAgent extends Node3D:
	var player = 0
	var health_obj = null

	func _init(p_pos: Vector3, p_player: int):
		position = p_pos
		player = p_player
		add_to_group("Attackable")

	func return_player():
		return player

	func get_health():
		return health_obj

# Mock Health class
class MockHealth:
	var hp = 10
	func return_health():
		return hp

func _ready():
	print("Starting AgentTracking Logic Test...")

	# Instantiate AgentTracking
	var tracking_script = load("res://Scripts/SensorNodes/agent_tracking.gd")
	var tracking = tracking_script.new()
	add_child(tracking)

	# Configure Tracking
	var me = MockAgent.new(Vector3.ZERO, 1) # Player 1
	add_child(me)
	tracking.my_agent = me # updated property
	tracking.target_bias = "Nearest"
	tracking.target_opposing = true
	tracking.target_same_team = false

	print("--- Setup Complete ---")

	# ---------------------------------------------------------
	# Test 1: First enemy enters (Far)
	# Expectation: Becomes target because current is null.
	# ---------------------------------------------------------
	var enemy_far = MockAgent.new(Vector3(100, 0, 0), 2) # Player 2 (Enemy)
	add_child(enemy_far)

	tracking._on_body_entered(enemy_far)

	if tracking.get_target() == enemy_far:
		print("PASS: First enemy (Far) became target.")
	else:
		print("FAIL: First enemy did not become target. Current: ", tracking.get_target())

	# ---------------------------------------------------------
	# Test 2: Second enemy enters (Close)
	# Expectation: Switches target because it is closer (better).
	# ---------------------------------------------------------
	var enemy_close = MockAgent.new(Vector3(50, 0, 0), 2)
	add_child(enemy_close)

	tracking._on_body_entered(enemy_close)

	if tracking.get_target() == enemy_close:
		print("PASS: Closer enemy became target.")
	else:
		print("FAIL: Closer enemy did not become target. Current: ", tracking.get_target())

	# ---------------------------------------------------------
	# Test 3: Third enemy enters (Farther than current)
	# Expectation: DOES NOT switch target. Optimization should prevent reselection.
	# ---------------------------------------------------------
	var enemy_farthest = MockAgent.new(Vector3(200, 0, 0), 2)
	add_child(enemy_farthest)

	tracking._on_body_entered(enemy_farthest)

	if tracking.get_target() == enemy_close:
		print("PASS: Farthest enemy did not steal target.")
	else:
		print("FAIL: Target switched incorrectly to farthest enemy. Current: ", tracking.get_target())

	# ---------------------------------------------------------
	# Test 4: Current target exits
	# Expectation: Reselects next best (enemy_far).
	# ---------------------------------------------------------
	print("--- Simulate Exit ---")
	tracking._on_body_exited(enemy_close)

	if tracking.get_target() == enemy_far:
		print("PASS: Target switched back to next best (Far) after Close exited.")
	elif tracking.get_target() == enemy_farthest:
		# Could happen if distance calc or list order matters, but 100 < 200.
		print("FAIL: Target switched to Farthest (200) instead of Far (100).")
	else:
		print("FAIL: Target lost or invalid. Current: ", tracking.get_target())

	print("AgentTracking Logic Test Finished.")
	get_tree().quit()
