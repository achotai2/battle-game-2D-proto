extends Node3D
class_name BuildingDeath

@export var deathTimeSeconds: float = 3.0

func trigger_death() -> void:
	# 1. Grab the main building
	var boss = ComponentFinder.get_base(self)
	
	# 2. PRO-TIP: Instantly disable collision so units don't get stuck on the dying building
	if is_instance_valid(boss) and "collision_layer" in boss:
		boss.collision_layer = 0
		boss.collision_mask = 0

	# 3. Wait for exactly 1.0 second
	await get_tree().create_timer(deathTimeSeconds).timeout
	
	# --- EVERYTHING BELOW THIS LINE HAPPENS after timeout LATER ---
	
	# Safety check: Make sure the game didn't restart or delete the building while we were waiting!
	if not is_instance_valid(boss):
		return
		
	# 4. Finally, wipe the building from the world
	boss.queue_free()
