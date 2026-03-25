extends Node
class_name GoldGiver

@export var visual_spawn_delay: float = 0.1
@export var max_visual_coins: int = 15 # Safety limit to prevent lag spikes!

@onready var goldDisplay = preload("res://Scenes/Resources/Gold.tscn")


func give_gold(target: Node3D, amount: int) -> bool:
	if amount <= 0 or not is_instance_valid(target):
		return false
		
	# Find target wallet
	var target_wallet: GoldWallet = target.get("gold_wallet")

	if target_wallet:
		# 1. THE MATH: Do the logical transfer instantly so the economy is perfectly accurate
		target_wallet.add_gold(amount)
		
	# 2. THE VISUALS: Start the asynchronous visual fountain
	_cascade_visuals(target, amount)
	return true


func _cascade_visuals(target: Node3D, amount: int) -> void:
	# Cap the number of physical coins we spawn so the engine doesn't crash
	var coins_to_spawn = min(amount, max_visual_coins)
	
	for i in range(coins_to_spawn):
		# Safety check: If the target died or got deleted mid-cascade, stop spawning!
		if not is_instance_valid(target):
			break
			
		_spawn_single_coin(target)
		
		# Pause this specific loop for a fraction of a second before continuing
		await get_tree().create_timer(visual_spawn_delay).timeout


func _spawn_single_coin(target: Node3D) -> void:
	if not goldDisplay:
		return
		
	var gold_instance = goldDisplay.instantiate() as GoldResource
	get_tree().current_scene.add_child(gold_instance)
	
	# Figure out where we are starting from
	var boss = ComponentFinder.get_base(self)
	if boss:
		var start_pos = boss.global_position
		start_pos.y += 1.0 # Start a bit above the ground
		
		# Add a tiny bit of random scatter so the coins don't spawn inside each other!
		var random_offset = Vector3(
			randf_range(-0.3, 0.3), 
			randf_range(0.0, 0.5), 
			randf_range(-0.3, 0.3)
		)
	
		# Tell the coin to start flying!
		gold_instance.on_create(start_pos + random_offset, target)
	else:
		print_debug("GoldGiver does not have a boss!")
