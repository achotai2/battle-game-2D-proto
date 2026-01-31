extends Area2D
class_name ArrowProjectileArc

const GRAVITY: float = 981.0

@export_range(-180, 180, 5) var camera_angle: int = 60
@export var launch_height: float = 1.0

# When descending and below this height, the arrow can hit bodies
@export var hit_height: float = 10.0

# Visual scaling: scale up as it gets higher
@export var max_scale_boost: float = 0.25   # 0.25 = +25% at peak
@export var max_lifetime: float = 4.0

# Stick behavior
@export var stick_into_target: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var death_timer: Timer = $DeathTimer

var _attack_data: AttackData
var position2d: Vector2
var target_position2d: Vector2
var velocity_z: float = 0.0
var velocity_2d: Vector2 = Vector2.ZERO
var height: float = 0.0
var _peak_height: float = 1.0
var _age: float = 0.0
var _landed: bool = false
var _armed: bool = false   # “can hit bodies yet”


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true
	shape.disabled = false

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("flying"):
		sprite.play("flying")

	death_timer.one_shot = true


func init(spawn_pos: Vector2, target_pos: Vector2, projectile_speed: float, attack_data: AttackData) -> void:
	_attack_data = attack_data
	position2d = spawn_pos
	target_position2d = target_pos

	height = launch_height
	_age = 0.0
	_landed = false
	_armed = false

	_calculate_start_values(projectile_speed)
	global_position = _new_global_position()
	_apply_visual_scale()


func _process(delta: float) -> void:
	if _landed:
		return

	_age += delta
	if _age >= max_lifetime:
		queue_free()
		return

	# --- integrate Z ---
	height += velocity_z * delta
	velocity_z -= GRAVITY * delta

	# --- integrate 2D ---
	position2d += velocity_2d * delta

	# --- update world position ---
	var new_pos := _new_global_position()
	_change_sprite_angle(new_pos)
	global_position = new_pos

	# --- arm logic: only hittable when descending and low enough ---
	_armed = (velocity_z < 0.0 and height <= hit_height)

	# --- visuals ---
	_apply_visual_scale()

	# --- ground hit ---
	if height <= 0.0:
		_land(null)


func _on_body_entered(body: Node2D) -> void:
	if _landed:
		return
	if not _armed:
		return
	if body == _attack_data.attacker:
		return

	# “Hit anyone”: no team filtering here.
	var h: Object = body.get("health")
	if not is_instance_valid(h):
		return
	h.apply_hit(_attack_data)

	_land(body)


func _land(hit_target: Node2D) -> void:
	if _landed:
		return
	_landed = true

	# Stop further hit checks
	monitoring = false
	monitorable = false
	shape.disabled = true

	# Clamp height for ground
	height = max(launch_height, 0.0)
	_apply_visual_scale()

	# Switch animation
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("landed"):
		sprite.play("landed")

	# Stick into target (keep world transform)
	if stick_into_target and is_instance_valid(hit_target):
		reparent(hit_target, true)

	# Disappear shortly
	death_timer.start()


func _new_global_position() -> Vector2:
	# fake camera tilt: higher Z lifts sprite upward on screen
	return Vector2(position2d.x, position2d.y - (height * tan(deg_to_rad(camera_angle))))


func _change_sprite_angle(look_to: Vector2) -> void:
	look_at(look_to)


func _apply_visual_scale() -> void:
	# Smooth scale based on height relative to peak height
	if _peak_height <= 0.001:
		return

	var t: float = clamp(height / _peak_height, 0.0, 1.0)
	var s: float = 1.0 + max_scale_boost * t
	scale = Vector2.ONE * s


func _calculate_start_values(projectile_speed: float) -> void:
	var distance_to: float = position2d.distance_to(target_position2d)

	var v2 := projectile_speed * projectile_speed
	var v4 := v2 * v2
	var g := GRAVITY

	# Discriminant for ballistic arc
	var disc := v4 - (g * g * distance_to * distance_to) + (2.0 * g * v2 * launch_height)

	# If target is too far for the speed, just shoot flat
	if disc <= 0.0 or distance_to <= 0.001:
		velocity_z = 0.0
		velocity_2d = position2d.direction_to(target_position2d) * projectile_speed
		_peak_height = max(launch_height, 1.0)
		return

	var s := sqrt(disc)
	var n := g * distance_to

	var high := atan((v2 + s) / n)
	var low := atan((v2 - s) / n)

	# Choose a reasonable arc (avoid overly high lob)
	var start_angle_z: float = low if high > 0.785398 else high

	velocity_z = sin(start_angle_z) * projectile_speed
	var speed_2d: float = abs(cos(start_angle_z) * projectile_speed)
	velocity_2d = position2d.direction_to(target_position2d) * speed_2d

	# Estimate peak height for scaling (h_peak = h0 + vz^2 / (2g))
	_peak_height = max(launch_height + (velocity_z * velocity_z) / (2.0 * GRAVITY), 1.0)

	_change_sprite_angle(target_position2d)


func _on_death_timer_timeout() -> void:
	queue_free()
