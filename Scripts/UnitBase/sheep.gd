extends AgentBase

@export var castle: Castle
@export var movement: AgentMovement
@export var animate: AgentAnimate
@export var food: HungerHolder
@export var foodWorkSite: WorkSite
@export var despawn_timer: Timer = null
@export var hop_radius: float = 100.0
@export var wander_interval: float = 2.0 # Not actively used by MinionPathfinding but kept for API compatibility if needed

var _spawn_position: Vector3
var patrol_anchor: Node3D = null
var is_returning: bool = false


func _ready() -> void:
	# Create a stationary anchor for the sheep to patrol around
	call_deferred("_set_marker")

	_connect_all_refs()

	patrol_anchor = Node3D.new()
	add_child(patrol_anchor)

	# Configure movement speeds
	# movement.can_meander no longer supported in simplified AgentMovement

	if despawn_timer:
		if not despawn_timer.timeout.is_connected(_on_despawn_timer_timeout):
			despawn_timer.timeout.connect(_on_despawn_timer_timeout)
		if despawn_timer.is_stopped():
			despawn_timer.start()
			
	


func _exit_tree() -> void:
	if patrol_anchor:
		patrol_anchor.queue_free()


func _connect_all_refs() -> void:
	_assign_animation_refs()
	_assign_movement_refs()
	_assign_food_worksite_refs()
	_assign_food_refs()


func _assign_animation_refs() -> void:
	if animate:
		animate.set_my_agent(self)


func _assign_movement_refs() -> void:
	if not movement:
		return

	movement.agent = self
	movement.animation = animate


func _assign_food_worksite_refs() -> void:
	if not foodWorkSite.work_completed.is_connected(_food_harvested):
		foodWorkSite.work_completed.connect(_food_harvested)


func _assign_food_refs() -> void:
	if not food.food_handed.is_connected(_food_handed):
		food.food_handed.connect(_food_handed)


func _physics_process(delta: float) -> void:
	if movement:
		movement.tick(delta)

	move_and_slide()

	if is_returning:
		# Use distance_squared_to to avoid expensive sqrt every physics frame
		if global_position.distance_squared_to(_spawn_position) < 100.0:
			queue_free()


func _on_despawn_timer_timeout() -> void:
	is_returning = true
	if movement:
		# Stop meandering and move to spawn
		movement.move_to_position(_spawn_position)
		
	_unregister_self()


func _food_handed() -> void:
	_unregister_self()
	queue_free()


func _food_harvested(f: WorkSite, _attacker: AgentBase) -> void:
	# Spawn food and hand it over to attacker.
	var attackerNode: AgentBase = _attacker
	if is_instance_valid(attackerNode.hunger) and attackerNode.hunger.has_method("receive_food"):
		food.give_food(attackerNode, food.food)


func return_position() -> Vector3:
	return global_position


func return_castle() -> Castle:
	return castle


func set_castle(c: Castle) -> void:
# Set castle and register myself with it, and apply for work.
	castle = c

	foodWorkSite._resolve_castle_and_register()
	foodWorkSite.needs_work()


func _unregister_self() -> void:
	# Unregister from job board.
	foodWorkSite._unregister_from_job_board()


func _set_marker() -> void:
	_spawn_position = global_position
	patrol_anchor.name = "SheepAnchor_" + str(get_instance_id())
	patrol_anchor.global_position = _spawn_position
