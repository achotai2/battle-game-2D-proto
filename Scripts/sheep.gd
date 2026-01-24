extends CharacterBody2D

@export var movement: AgentMovement
@export var pathfinding: MinionPathfinding
@export var animate: AgentAnimate
@export var despawn_timer: Timer = null
@export var move_speed: float = 50.0
@export var hop_radius: float = 100.0
@export var wander_interval: float = 2.0

var spawn_position: Vector2
var target_position: Vector2
var is_returning: bool = false
var wander_timer: float = 0.0

func _ready() -> void:
	spawn_position = global_position
	# Initialize target as current spot
	target_position = global_position

	if despawn_timer:
		if not despawn_timer.timeout.is_connected(_on_despawn_timer_timeout):
			despawn_timer.timeout.connect(_on_despawn_timer_timeout)
		# Ensure timer is running if not autostart
		if despawn_timer.is_stopped():
			despawn_timer.start()

func _physics_process(delta: float) -> void:
	if is_returning:
		var direction = global_position.direction_to(spawn_position)
		velocity = direction * move_speed
		move_and_slide()

		if global_position.distance_to(spawn_position) < 5.0:
			queue_free()
	else:
		# Wandering behavior
		wander_timer -= delta
		if wander_timer <= 0:
			wander_timer = wander_interval
			_pick_random_target()

		if global_position.distance_to(target_position) > 5.0:
			var direction = global_position.direction_to(target_position)
			velocity = direction * move_speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func _pick_random_target() -> void:
	var random_offset = Vector2(randf_range(-hop_radius, hop_radius), randf_range(-hop_radius, hop_radius))
	target_position = spawn_position + random_offset

func _on_despawn_timer_timeout() -> void:
	is_returning = true

func attack(_attacker: Node) -> void:
	# Spawn food
	var food_scene = ResourceSiteDefs.get_scene(ResourceSiteDefs.ResourceType.FOOD)
	if food_scene:
		var food = food_scene.instantiate()
		food.global_position = global_position
		get_parent().call_deferred("add_child", food)

	queue_free()
