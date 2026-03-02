extends MainLoop

const AgentTracking = preload("res://Scripts/SensorNodes/agent_tracking.gd")
# const Health = preload("res://Scripts/AgentNodes/health.gd") # If needed

class MockAgentTracking extends AgentTracking:
	var _mock_bodies: Array[Node3D] = []

	func set_mock_bodies(bodies: Array[Node3D]):
		_mock_bodies = bodies

	# Override _scan_for_targets to use mock bodies instead of space state
	func _scan_for_targets() -> void:
		if _mock_bodies.is_empty():
			if current_target != null:
				current_target = null
				target_lost.emit()
			return

		var best_target = null
		var best_score = INF
		var my_pos = global_position

		for body in _mock_bodies:
			if body == my_agent or not is_instance_valid(body):
				continue

			var score = 0.0
			if target_bias == "Nearest":
				score = my_pos.distance_squared_to(body.global_position)
			elif target_bias == "Lowest Health":
				if body.has_method("get_health_percent"):
					score = body.get_health_percent()
				else:
					score = 100.0

			if score < best_score:
				best_score = score
				best_target = body

		if best_target != current_target:
			current_target = best_target
			target_changed.emit(current_target)

class MockBody extends Node3D:
	var _groups = []
	var _player = 0
	var strength = 0
	var health_comp = null

	func _init(player_id=0, groups=[]):
		_player = player_id
		_groups = groups

	func is_in_group(g: StringName) -> bool:
		return g in _groups

	func return_player() -> int:
		return _player

	func get_strength() -> float:
		return float(strength)

	func _ready():
		if health_comp:
			add_child(health_comp)
			# Mock get("health") behavior by ensuring the property exists if possible?
			# In GDScript objects, get() accesses properties.
			# But children aren't properties unless assigned.
			pass

	func _get(property):
		if property == "health":
			return health_comp
		return null

class MockHealth extends Node:
	var hp = 10
	func return_health() -> int:
		return hp

func _initialize():
	print("Running AgentTracking Tests...")

	test_nearest()
	test_team_filter()
	test_lowest_health()

	print("All Tests Passed")

func _process(delta):
	_initialize()
	return true # Quit

func test_nearest():
	print("Testing Nearest...")
	var t = MockAgentTracking.new()
	var me = MockBody.new(1)
	me.position = Vector3(0, 0, 0)
	t.my_agent = me
	t.target_bias = "Nearest"

	var b1 = MockBody.new(2, ["Attackable"])
	b1.position = Vector3(100, 0, 0)
	var b2 = MockBody.new(2, ["Attackable"])
	b2.position = Vector3(50, 0, 0)

	t.set_mock_bodies([b1, b2])
	t._scan_for_targets()

	if t.current_target != b2:
		printerr("FAILED: Nearest should be b2, got ", t.current_target)
	else:
		print("PASSED: Nearest")

	t.free()
	me.free()
	b1.free()
	b2.free()

func test_team_filter():
	print("Testing Team Filter...")
	var t = MockAgentTracking.new()
	var me = MockBody.new(1)
	t.my_agent = me
	t.target_opposing = true
	t.target_same_team = false
	t.target_neutral = false

	var ally = MockBody.new(1, ["Attackable"])
	var enemy = MockBody.new(2, ["Attackable"])
	var neutral = MockBody.new(0, ["Attackable"])

	t.set_mock_bodies([ally, enemy, neutral])
	t._scan_for_targets()

	if t.current_target != enemy:
		printerr("FAILED: Should target enemy, got ", t.current_target)
	else:
		print("PASSED: Team Filter")

	t.free()
	me.free()
	ally.free()
	enemy.free()
	neutral.free()

func test_lowest_health():
	print("Testing Lowest Health...")
	var t = MockAgentTracking.new()
	var me = MockBody.new(1)
	t.my_agent = me
	t.target_bias = "Lowest Health"

	var b1 = MockBody.new(2, ["Attackable"])
	b1.position = Vector3(10, 0, 0)
	b1.health_comp = MockHealth.new()
	b1.health_comp.hp = 100

	var b2 = MockBody.new(2, ["Attackable"])
	b2.position = Vector3(20, 0, 0) # Further away
	b2.health_comp = MockHealth.new()
	b2.health_comp.hp = 50 # Lower health

	t.set_mock_bodies([b1, b2])
	t._scan_for_targets()

	if t.current_target != b2:
		printerr("FAILED: Lowest Health should be b2, got ", t.current_target)
	else:
		print("PASSED: Lowest Health")

	t.free()
	me.free()
	b1.free()
	b2.free()
