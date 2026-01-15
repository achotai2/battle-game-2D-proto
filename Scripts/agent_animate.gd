extends Node
class_name AgentAnimate

signal interactAnimationFinished
signal attackAnimationFinished

@export var sprite: AnimatedSprite2D
@export_range(0, 3, 0.1) var damageVisualTime: float = 0.2

var damageTimer := Timer.new()
var attacking: bool = false
var working: bool = false

var _my_agent: Node2D = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# The damage flash timer.
	damageTimer.wait_time = damageVisualTime
	damageTimer.one_shot = true
	damageTimer.timeout.connect(_on_timer_timeout)
	add_child(damageTimer)

	if sprite:
		sprite.animation_finished.connect(_animation_finished)
		_animation_finished()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !damageTimer.is_stopped():
		_update_damage_visual()


func _update_damage_visual() -> void:
	if is_instance_valid(sprite) and is_instance_valid(sprite.material):
		var percent: float = float(damageTimer.wait_time - damageTimer.time_left) / damageTimer.wait_time
		sprite.material.set_shader_parameter("progress", percent)
#		animation.position = Vector2(randi_range(-1, 1), randi_range(-1, 1))


func _animation_finished() -> void:
	if attacking:
		attackAnimationFinished.emit()

	if working:
		interactAnimationFinished.emit()

	if is_instance_valid(sprite):
		attacking = false
		working = false
		sprite.play("idle")
	

func _on_timer_timeout() -> void:
	if is_instance_valid(sprite) and is_instance_valid(sprite.material):
		sprite.material.set_shader_parameter("progress", 0)
#		animation.position = Vector2(0, 0)


func set_my_agent(ag: Node2D) -> void:
	_my_agent = ag


#func _health_connect() -> void:
	#if is_instance_valid(health):
		#health.tookDamage.connect(_show_damage)
		#health.tookHeal.connect(_show_heal)


func agent_moved(velocity: Vector2) -> void:
# Called by Agent when movement occurs, to run animation.
	if sprite and not attacking and not working:
		if velocity != Vector2(0, 0):
			sprite.play("walk")

			if velocity.x < 0:
				sprite.flip_h = true
			elif velocity.x > 0:
				sprite.flip_h = false
			
		else:
			if is_instance_valid(sprite):
				sprite.play("idle")


func _show_damage() -> void:
	damageTimer.start()


func _show_heal() -> void:
	pass


func play_attack(target: Node2D) -> void:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return

	attacking = true
	var dir: Vector2 = _my_agent.return_position().direction_to(target.return_position())
	var frames := sprite.sprite_frames

	var variant := "attack1"
	if frames.has_animation("attack2") and randf() < 0.25:
		variant = "attack2"

	var anim := variant
	if abs(dir.y) > abs(dir.x):
		anim = variant + ("Up" if dir.y < 0 else "Down")
		sprite.flip_h = false
	else:
		sprite.flip_h = dir.x < 0

	# Fallbacks if a unit lacks Up/Down
	if not frames.has_animation(anim):
		anim = variant
	if not frames.has_animation(anim):
		anim = "attack1" if frames.has_animation("attack1") else ""

	if anim != "":
		sprite.play(anim)


func set_sprite_frames(frames: SpriteFrames) -> void:
	if not is_instance_valid(sprite):
		push_warning("AgentAnimate.set_sprite_frames(): sprite not bound")
		return

	if sprite.sprite_frames == frames:
		return

	# Stop current animation cleanly
	sprite.stop()

	sprite.sprite_frames = frames

	# Reset animation state safely
	attacking = false
	working = false
	#sprite.flip_h = false

	# Pick a safe default animation
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	elif sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play(sprite.sprite_frames.get_animation_names()[0])


func cancel_action_state() -> void:
	# Called by apply_role in agent.
	attacking = false
	working = false
	# optionally stop attack anim
	sprite.stop()


func do_work() -> void:
	# Called by tactical worker when work is performed.
	working = true
	var frames := sprite.sprite_frames
	if frames.has_animation("work"):
		sprite.play("work")
