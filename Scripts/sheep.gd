extends CharacterBody2D

@export var movement: AgentMovement
@export var pathfinding: MinionPathfinding
@export var animate: AgentAnimate
@export var despawn_timer: Timer = null
@export var hop_radius: float = 100.0
@export var wander_interval: float = 2.0 # Not actively used by MinionPathfinding but kept for API compatibility if needed

var spawn_position: Vector2
var patrol_anchor: Node2D = null
var is_returning: bool = false


func _ready() -> void:
	spawn_position = global_position

	# Create a stationary anchor for the sheep to patrol around
	patrol_anchor = Node2D.new()
	patrol_anchor.name = "SheepAnchor_" + str(get_instance_id())
	patrol_anchor.global_position = spawn_position
	# Add to parent so it doesn't move with the sheep
	get_parent().call_deferred("add_child", patrol_anchor)

	_connect_all_refs()

	# Configure movement speeds
	if is_instance_valid(movement):
		movement.can_meander = true

	# Configure pathfinding
	if is_instance_valid(pathfinding):
		pathfinding.patrol_radius = hop_radius
		pathfinding.patrol_pause_seconds = wander_interval
		# The anchor is the "castle" we patrol around
		pathfinding.set_castle(patrol_anchor)

	if despawn_timer:
		if not despawn_timer.timeout.is_connected(_on_despawn_timer_timeout):
			despawn_timer.timeout.connect(_on_despawn_timer_timeout)
		if despawn_timer.is_stopped():
			despawn_timer.start()


func _exit_tree() -> void:
	if is_instance_valid(patrol_anchor):
		patrol_anchor.queue_free()


func _connect_all_refs() -> void:
	_assign_animation_refs()
	_assign_movement_refs()
	_assign_pathfinding_refs()


func _assign_animation_refs() -> void:
	if is_instance_valid(animate):
		animate.set_my_agent(self)


func _assign_movement_refs() -> void:
	if not is_instance_valid(movement):
		return

	if movement.has_method("set_my_agent"):
		movement.call("set_my_agent", self)
	if movement.has_method("set_animation"):
		movement.call("set_animation", animate)
	if movement.has_method("set_pathfinding"):
		movement.call("set_pathfinding", pathfinding)


func _assign_pathfinding_refs() -> void:
	if not is_instance_valid(pathfinding):
		return
	# We set the castle (anchor) in _ready, but this mimics AgentBase structure
	if pathfinding.has_method("set_castle"):
		pathfinding.call("set_castle", patrol_anchor)


func _physics_process(delta: float) -> void:
	if is_instance_valid(movement):
		movement.tick(delta)

	move_and_slide()

	if is_returning:
		if global_position.distance_to(spawn_position) < 10.0:
			queue_free()


func _on_despawn_timer_timeout() -> void:
	is_returning = true
	if is_instance_valid(movement):
		# Stop meandering and move to spawn
		movement.command_move_to_position(spawn_position)


func attack(_attacker: Node2D) -> void:
	# Spawn food
	var food_scene = ResourceSiteDefs.get_scene(ResourceSiteDefs.ResourceType.FOOD)
	if food_scene:
		var food = food_scene.instantiate()
		food.global_position = global_position
		get_parent().call_deferred("add_child", food)

	queue_free()


func return_position() -> Vector2:
	return global_position
