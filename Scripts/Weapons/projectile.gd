extends Area3D
class_name ArrowProjectileArc

# 9.81 is standard Earth gravity. 
# If your arrows float too much, increase this to ~20.0 for a snappier "video game" arc!
const GRAVITY: float = 1.0 

@export var max_lifetime: float = 4.0
@export var stick_into_target: bool = true

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var death_timer: Timer = $DeathTimer

var _attack_data: AttackData
var velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _landed: bool = false


func _ready() -> void:
	collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_PROJECTILE)
	collision_mask = GamePhysics.get_projectile_mask()

	body_entered.connect(_on_body_entered)
	
	# Hook up the timer!
	death_timer.timeout.connect(_on_death_timer_timeout)
	death_timer.one_shot = true

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("flying"):
		sprite.play("flying")


func init(spawn_pos: Vector3, impact_pos: Vector3, speed: float, attack_data: AttackData) -> void:
	_attack_data = attack_data
	global_position = spawn_pos
	_age = 0.0
	_landed = false

	# 1. Calculate flat horizontal direction and distance
	var direction = impact_pos - spawn_pos
	var height_difference = direction.y
	direction.y = 0.0 # Flatten it out to get pure ground distance
	
	var distance = direction.length()
	var flat_direction = direction.normalized()
	
	# 2. Time in the air is simply ground distance divided by speed
	var time = distance / speed
	if time <= 0.0: time = 0.01 # Prevent divide by zero if firing point-blank
	
	# 3. Calculate the exact vertical velocity needed to hit the target at that time
	var initial_vy = (height_difference + 0.5 * GRAVITY * (time * time)) / time
	
	# 4. Combine into a true 3D velocity vector
	velocity = flat_direction * speed
	velocity.y = initial_vy
	
	_update_rotation()


func _process(delta: float) -> void:
	if _landed:
		return

	_age += delta
	if _age >= max_lifetime:
		queue_free()
		return

	# Apply gravity to the Y axis
	velocity.y -= GRAVITY * delta
	
	# Move the arrow through 3D space
	global_position += velocity * delta
	
	# Point the arrow in the direction it is currently flying
	_update_rotation()

	# Ground hit fallback (assuming y=0 is your floor)
	if global_position.y <= 0.0:
		_land(null)


func _update_rotation() -> void:
	# Avoid look_at errors if the arrow is somehow perfectly still
	if velocity.length_squared() > 0.01:
		# look_at requires a point in space, so we add velocity to current position
		look_at(global_position + velocity, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if _landed:
		return
		
	if body == _attack_data.attacker:
		return

	# THE FIX: Use ComponentFinder exactly like the melee weapon!
	var h: Health = ComponentFinder.get_component(body, "Health")
	if is_instance_valid(h):
		h.apply_hit(_attack_data)

	_land(body)


func _land(hit_target: Node3D) -> void:
	if _landed:
		return
	_landed = true

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	shape.set_deferred("disabled", true)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("landed"):
		sprite.play("landed")

	if stick_into_target and is_instance_valid(hit_target):
		call_deferred("reparent", hit_target, true)

	death_timer.start()


func _on_death_timer_timeout() -> void:
	queue_free()
