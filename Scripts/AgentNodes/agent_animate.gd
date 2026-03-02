extends Node
class_name AgentAnimate

signal interactAnimationFinished
signal attackAnimationFinished

@export var sprite: AnimatedSprite3D
@export_range(0, 3, 0.1) var damageVisualTime: float = 0.2

var damageTimer := Timer.new()
var attacking: bool = false
var working: bool = false

var _move_anim: StringName = &""
var _my_agent: AgentBase = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not sprite:
		sprite = ComponentFinder.get_component(self, "AnimatedSprite3D") as AnimatedSprite3D
		
	# The damage flash timer.
	damageTimer.wait_time = damageVisualTime
	damageTimer.one_shot = true
	damageTimer.timeout.connect(_on_timer_timeout)
	add_child(damageTimer)

	if sprite:
		_update_move_anim_cache()
		sprite.animation_finished.connect(_animation_finished)
		_animation_finished()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !damageTimer.is_stopped():
		_update_damage_visual()


func _update_damage_visual() -> void:
	if is_instance_valid(sprite):
		var percent: float = float(damageTimer.wait_time - damageTimer.time_left) / damageTimer.wait_time
		sprite.set_instance_shader_parameter("progress", percent)
#		animation.position = Vector3(randi_range(-1, 1), randi_range(-1, 1))


func _animation_finished() -> void:
	if attacking:
		attackAnimationFinished.emit()

	if working:
		interactAnimationFinished.emit()

	if is_instance_valid(sprite):
		attacking = false
		# working = false # Removed to allow looping work animation
		_update_idle_walk_anim()
	

func _on_timer_timeout() -> void:
	if is_instance_valid(sprite):
		sprite.set_instance_shader_parameter("progress", 0.0)
#		animation.position = Vector3(0, 0, 0)


func _update_idle_walk_anim() -> void:
	var vel = Vector3.ZERO
	if is_instance_valid(_my_agent) and "velocity" in _my_agent:
		vel = _my_agent.velocity
	agent_moved(vel)


func set_my_agent(ag: AgentBase) -> void:
	_my_agent = ag


#func _health_connect() -> void:
	#if is_instance_valid(health):
		#health.tookDamage.connect(_show_damage)
		#health.tookHeal.connect(_show_heal)


func agent_moved(velocity: Vector3) -> void:
# Called by Agent when movement occurs, to run animation.
	if not is_instance_valid(sprite):
		return 

	if not attacking and not working:
		if velocity != Vector3(0, 0, 0):
			if _move_anim != &"":
				sprite.play(_move_anim)

			if velocity.x < 0:
				sprite.flip_h = true
			elif velocity.x > 0:
				sprite.flip_h = false
			
		else:
			sprite.play("idle")


func _show_damage() -> void:
	damageTimer.start()


func _show_heal() -> void:
	pass


func play_attack(target: Node3D) -> bool:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return false

	attacking = true
	working = false
	var dir: Vector3 = _my_agent.global_position.direction_to(target.global_position)
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
		return true
	return false


func set_sprite_frames(frames: SpriteFrames) -> void:
	if not is_instance_valid(sprite):
		push_warning("AgentAnimate.set_sprite_frames(): sprite not bound")
		return

	if sprite.sprite_frames == frames:
		return

	# Stop current animation cleanly
	sprite.stop()

	sprite.sprite_frames = frames
	_update_move_anim_cache()

	# Reset animation state safely
	attacking = false
	working = false
	#sprite.flip_h = false

	# Pick a safe default animation
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	elif sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play(sprite.sprite_frames.get_animation_names()[0])

func _update_move_anim_cache() -> void:
	_move_anim = &""
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("walk"):
		_move_anim = &"walk"
	elif sprite.sprite_frames.has_animation("run"):
		_move_anim = &"run"


func cancel_action_state() -> void:
	# Called by apply_role in agent.
	attacking = false
	working = false
	# optionally stop attack anim
	if is_instance_valid(sprite):
			sprite.stop()


func play_work() -> bool:
	# Called by tactical worker / interaction when work is performed.
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return false

	var frames := sprite.sprite_frames
	if frames.has_animation("work"):
		working = true
		attacking = false
		sprite.play("work")
		return true
	return false
