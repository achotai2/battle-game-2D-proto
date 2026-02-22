extends Node

func _ready():
	print("Starting HungerHolder Refactor Test")

	var holder = HungerHolder.new()
	# We can't add_child here easily without a scene tree context for _ready to auto-run?
	# But we can call _ready manually or add to self.
	add_child(holder)

	# Wait for _ready? add_child triggers _ready immediately in Godot?
	# Usually yes.

	var storage = holder.find_child("FoodStorage", false, false)
	if storage:
		print("PASS: FoodStorage found")
		if storage.food == 100:
			print("PASS: FoodStorage initialized with default food")
		else:
			print("FAIL: FoodStorage food = ", storage.food)
	else:
		print("FAIL: FoodStorage missing")

	var giver = holder.find_child("FoodGiver", false, false)
	if giver:
		print("PASS: FoodGiver found")
	else:
		print("FAIL: FoodGiver missing")

	var receiver = holder.find_child("FoodReceiver", false, false)
	if receiver:
		print("PASS: FoodReceiver found")
	else:
		print("FAIL: FoodReceiver missing")

	var sensor = holder.find_child("FoodSensor", false, false)
	if sensor:
		print("PASS: FoodSensor found")
	else:
		print("FAIL: FoodSensor missing")

	# Advisor won't be created because agent is null
	var advisor = holder.find_child("AdvisorHunger", false, false)
	if not advisor:
		print("PASS: AdvisorHunger not created (no agent)")
	else:
		print("FAIL: AdvisorHunger created unexpectedly")

	print("Test Complete")
	get_tree().quit()
