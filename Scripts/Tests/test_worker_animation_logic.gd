extends Node

# Test script for Worker Animation Logic
# run with: godot --headless -s Scripts/Tests/test_worker_animation_logic.gd

func _ready():
	print("Starting Worker Animation Logic Test...")

	# 1. Setup Mock Environment
	var agent = AgentBase.new()
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

	var nav_agent = NavigationAgent3D.new()
	agent.add_child(nav_agent)

	var move_script = load("res://Scripts/AgentNodes/agent_move.gd")
	var movement = move_script.new()
	movement.agent = agent
	movement.animation = animate
	movement.nav_agent = nav_agent
	agent.add_child(movement)

	# Initial setup call
	movement._ready()

	# 2. Test Movement Logic (Pathfinding)
	print("--- Test 1: Move to Position ---")
	var target_pos = Vector3(10, 0, 10)
	movement.move_to_position(target_pos)

	# Verify internal state
	if movement._mode == movement.Mode.PATHFINDING:
		print("PASS: Movement mode set to PATHFINDING")
	else:
		print("FAIL: Movement mode is ", movement._mode)

	# Simulate tick
	movement.tick(0.1)
	# Should trigger animation update if velocity > 0
	# But NavigationAgent3D needs frames to update path.
	# We can't easily mock NavAgent3D pathfinding in headless without map.
	# So we might not see velocity change immediately.
	# But we can verify `agent_moved` was called with 0 if no path yet.

	# 3. Test Manual Velocity (AdvisorPlayer)
	print("--- Test 2: Manual Velocity ---")
	var dir = Vector3(1, 0, 0)
	movement.move_in_direction(dir)

	if movement._mode == movement.Mode.VELOCITY:
		print("PASS: Movement mode set to VELOCITY")
	else:
		print("FAIL: Movement mode is ", movement._mode)

	movement.tick(0.1)
	if movement._current_velocity.length() > 0:
		print("PASS: Velocity updated")
	else:
		print("FAIL: Velocity zero")

	# 4. Test Work Animation Logic
	print("--- Test 3: Work Animation ---")
	# AdvisorWork logic: stop() then play_work()
	movement.stop()

	if movement._mode == movement.Mode.VELOCITY and movement._desired_velocity == Vector3.ZERO:
		print("PASS: Stopped correctly")
	else:
		print("FAIL: Did not stop correctly")

	animate.play_work()
	if animate.working:
		print("PASS: Animation state is WORKING")
	else:
		print("FAIL: Animation state is NOT WORKING")

	# 5. Test Move Cancels Work
	print("--- Test 4: Move Cancels Work ---")
	movement.move_to_position(Vector3(20, 0, 20))

	if not animate.working:
		print("PASS: Move command cleared Working state")
	else:
		print("FAIL: Move command did NOT clear Working state")

	# 6. Test Clear Movement
	print("--- Test 5: Clear Movement ---")
	movement.clear_movement()
	if movement._mode == movement.Mode.VELOCITY and movement._desired_velocity == Vector3.ZERO:
		print("PASS: clear_movement stopped agent")
	else:
		print("FAIL: clear_movement failed")


	print("Test Finished")
	get_tree().quit()
