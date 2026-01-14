extends StaticBody2D

@export var destroyed: bool = false
@export var construction: bool = false
@export var interact: ExternalInteract
@export var drawStuff: BuildingDraw
@export var health: Health
@export var chopTask: Task
@export var collision: CollisionShape2D
@export var spawnsGoblin: Spawns
@export var spawnsSheep: Spawns
@export var spawnPlant: Spawns


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(interact):
		interact.interactionFinished.connect(_interaction_finished)

	if is_instance_valid(drawStuff):
		drawStuff.update_draw_state(0, destroyed, construction)

	if is_instance_valid(health):
		health.healthDepleted.connect(_health_depleted)
		health.healthRestored.connect(_health_restored)
		health.tookDamage.connect(_take_damage)
		health.tookHeal.connect(_take_repair)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _interaction_finished(interactingPlayer: int) -> void:
	if !construction: # If destroyed then set it to being constructed.
		destroyed = false
		construction = true

		if is_instance_valid(health):
			health.set_health(1)

		if is_instance_valid(chopTask):
			chopTask.need_task()


	if drawStuff:
		drawStuff.update_draw_state(0, destroyed, construction)


func _health_depleted(attackingPlayer: int) -> void:
	if is_instance_valid(drawStuff):
		drawStuff.update_draw_state(0, destroyed, construction)


func _health_restored() -> void:
	# Construct the building.
	if !destroyed and construction:
		construction = false

		_tree_chopped()
		
	if is_instance_valid(drawStuff):
		drawStuff.update_draw_state(0, destroyed, construction)
	
	if is_instance_valid(chopTask):
		chopTask.task_finished()


func _tree_chopped() -> void:
	collision.disabled = true
	$NavigationObstacle2D.radius = 0
	spawnPlant.spawn_resource(1)
	spawnsGoblin.change_timer_to_spawn(false)
	spawnsSheep.change_timer_to_spawn(true)


func _on_castle_build_timer_timeout() -> void:
	destroyed = false
	construction = false
	health.restore_health()

	if is_instance_valid(drawStuff):
		drawStuff.update_draw_state(0, destroyed, construction)


func _take_damage() -> void:
	if is_instance_valid(drawStuff):
		drawStuff.received_damage()


func _take_repair() -> void:
	if is_instance_valid(drawStuff) and health.return_health() != health.return_max_health():
		drawStuff.received_build()


func _plant_picked_up() -> void:
	spawnPlant.spawn_resource(1)


####
# Called by other agents weapons or trackers or world.
####
func return_player() -> int:
	return 0


func return_position() -> Vector2:
	return self.global_position


func return_velocity() -> Vector2:
	return Vector2(0, 0)


func return_castle() -> Node:
	return null


func delete_me() -> void:
	self.queue_free()


func spawned_this_resource(spawned: Node) -> void:
	if spawned.is_in_group("Plants"):
		spawned.pickedUpIAm.connect(_plant_picked_up)
