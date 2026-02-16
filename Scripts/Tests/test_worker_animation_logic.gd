extends Node

# Test script for Worker Animation Logic
# run with: godot --headless -s Scripts/Tests/test_worker_animation_logic.gd

func _ready():
	print("Starting Worker Animation Logic Test...")

	# 1. Setup Mock Environment
	var agent = CharacterBody3D.new()
	add_child(agent)

	# Mock Sprite with Animations
	var sprite = AnimatedSprite3D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("work")
	frames.add_animation("idle")
	frames.add_animation("walk")
	frames.add_animation("attack1")
	sprite.sprite_frames = frames
	agent.add_child(sprite)

	# Instantiate Components
	var animate_script = load("res://Scripts/AgentNodes/agent_animate.gd")
	var animate = animate_script.new()
	animate.sprite = sprite
	animate.set_my_agent(agent)
	agent.add_child(animate)

	var nav_agent = NavigationAgent2D.new()
	agent.add_child(nav_agent)

	var move_script = load("res://Scripts/AgentNodes/agent_move.gd")
	var movement = move_script.new()
	movement.agent = agent
	movement.animation = animate
	movement.nav_agent = nav_agent
	# Disable auto-meander for controlled test
	movement.can_meander = false
	agent.add_child(movement)

	var tasker_script = load("res://Scripts/AgentNodes/minion_tasker.gd")
	var tasker = tasker_script.new()
	tasker.agent = agent
	tasker.movement = movement
	tasker.work_interval = 0.1 # Fast tick
	tasker.think_interval = 0.1
	agent.add_child(tasker)

	# Mock WorkSite
	var site = WorkSite.new()
	# Add methods dynamically or use script
	var site_script = GDScript.new()
	site_script.source_code = """
extends Node3D
var work_needed = true
func needs_work() -> bool: return work_needed
func apply_work(amount, worker): pass
func get_work_position_for(agent): return global_position
	"""
	site_script.reload()
	site.set_script(site_script)
	add_child(site)
	site.global_position = Vector3(100, 0, 100)

	# Wait for _ready
	await get_tree().process_frame

	print("--- Test 1: Assign Job and Move ---")
	tasker.assign_job(site)

	# Should be moving
	await get_tree().process_frame
	if movement._order_type == movement.OrderType.MOVE_TO_POS:
		print("PASS: Movement order set to MOVE_TO_POS")
	else:
		print("FAIL: Movement order is ", movement._order_type)

	print("--- Test 2: Arrive at Site and Work ---")
	# Simulate arrival
	agent.global_position = site.global_position
	# Tasker thinks periodically
	await get_tree().create_timer(0.2).timeout

	# Check if working
	# Note: In original code, tasker checks range and calls _enter_work_state.
	# With FIX, _enter_work_state should call movement.command_start_work.

	if movement._order_type == movement.OrderType.FROZEN:
		print("PASS: Movement is FROZEN (Working)")
	else:
		print("FAIL: Movement is NOT FROZEN. Type: ", movement._order_type)

	if animate.working:
		print("PASS: Animation state is WORKING")
	else:
		print("FAIL: Animation state is NOT WORKING")

	print("--- Test 3: Animation Loop Persistence ---")
	# Simulate animation finish
	if animate.has_signal("interactAnimationFinished"):
		# Manually trigger signal or call _animation_finished
		animate._animation_finished()

		if animate.working:
			print("PASS: Animation state PERSISTS after finish (Looping behavior)")
		else:
			print("FAIL: Animation state RESET after finish (Not looping)")

	print("--- Test 4: Verify Attacking Mutual Exclusivity ---")
	# Reset state manually for test or use commands
	# animate.play_attack(null) would fail due to null target logic probably
	# Let's just check the code logic via reflection or side effect

	# If we are working, and we attack
	# animate.working = true
	# animate.play_attack(...)
	# check working == false

	var dummy_target = CharacterBody3D.new()
	add_child(dummy_target)
	dummy_target.global_position = Vector3(200, 0, 200)

	animate.working = true
	animate.play_attack(dummy_target)

	if not animate.working:
		print("PASS: Play Attack cleared Working state")
	else:
		print("FAIL: Play Attack did NOT clear Working state")

	if animate.attacking:
		print("PASS: Attack state set")
	else:
		print("FAIL: Attack state NOT set")

	print("--- Test 5: Verify Working Mutual Exclusivity ---")
	# Reset
	animate.attacking = true
	animate.play_work()

	if not animate.attacking:
		print("PASS: Play Work cleared Attacking state")
	else:
		print("FAIL: Play Work did NOT clear Attacking state")

	if animate.working:
		print("PASS: Work state set")
	else:
		print("FAIL: Work state NOT set")

	print("--- Test 6: Cancel Work on Move ---")
	# Currently working (from Test 5)
	# Issue move command
	movement.command_move_to_position(Vector3(50, 0, 50), 10)

	if not animate.working:
		print("PASS: Move command cleared Working state")
	else:
		print("FAIL: Move command did NOT clear Working state")

	if movement._order_type == movement.OrderType.MOVE_TO_POS:
		print("PASS: Move command accepted")
	else:
		print("FAIL: Move command not accepted")

	print("Test Finished")
	get_tree().quit()
