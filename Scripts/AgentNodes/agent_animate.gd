extends Node
class_name AgentAnimate

signal interactAnimationFinished
signal attackAnimationFinished

@export var sprite: AnimatedSprite3D
@export_range(0, 3, 0.1) var damageVisualTime: float = 0.2

var damageTimer := Timer.new()
var _my_agent: Node3D = null
var _move_anim: StringName = &""


func _ready() -> void:
	# 1. Grab the base using the ComponentFinder
	if not _my_agent:
		_my_agent = ComponentFinder.get_base(self)
	
	# 2. THE FIX: Use ComponentFinder to grab the node directly! 
	# Do not rely on AgentBase's cached variables here because they don't exist yet!
	if not sprite and is_instance_valid(_my_agent):
		sprite = ComponentFinder.get_component(_my_agent, "AnimatedSprite3D") as AnimatedSprite3D

	# 3. Setup Damage Timer
	damageTimer.wait_time = damageVisualTime
	damageTimer.one_shot = true
	damageTimer.timeout.connect(_on_timer_timeout)
	add_child(damageTimer)

	# 4. Connect Signals and Cache Move Anim
	if is_instance_valid(sprite):
		_update_move_anim_cache()
		if not sprite.animation_finished.is_connected(_animation_finished):
			sprite.animation_finished.connect(_animation_finished)


func _process(_delta: float) -> void:
	if !damageTimer.is_stopped():
		_update_damage_visual()


func set_my_agent(ag: Node3D) -> void:
	_my_agent = ag


# ==========================================
# EXPLICIT API (CALL THESE FROM ADVISORS!)
# ==========================================

func play_idle() -> void:
	if not is_instance_valid(sprite): return
	
	if not _is_playing_action():
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


func play_walk(velocity: Vector3) -> void:
	if not is_instance_valid(sprite): return
	
	if _is_playing_action(): return 
	
	if velocity.length_squared() > 0.1:
		if _move_anim != &"":
			sprite.play(_move_anim)
			
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false
	else:
		play_idle()


func face_target(target_pos: Vector3) -> void:
	if not is_instance_valid(sprite) or not is_instance_valid(_my_agent): return
	sprite.flip_h = target_pos.x < _my_agent.global_position.x


func play_attack(target: Node3D) -> bool:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null: return false

	if _is_playing_action() and sprite.animation.begins_with("attack"):
		return true 

	var dir: Vector3 = _my_agent.global_position.direction_to(target.global_position)
	var frames := sprite.sprite_frames

	var variant := "attack1"
	if frames.has_animation("attack2") and randf() < 0.25:
		variant = "attack2"

	var anim := variant
	
	if abs(dir.z) > abs(dir.x):
		anim = variant + ("Up" if dir.z < 0 else "Down")
		sprite.flip_h = false
	else:
		sprite.flip_h = dir.x < 0

	if not frames.has_animation(anim): anim = variant
	if not frames.has_animation(anim): anim = "attack1" if frames.has_animation("attack1") else ""

	if anim != "":
		sprite.play(anim)
		return true
		
	return false


func play_work() -> bool:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null: return false
	
	if _is_playing_action() and sprite.animation == "work":
		return true

	if sprite.sprite_frames.has_animation("work"):
		sprite.play("work")
		return true
		
	return false


# ==========================================
# INTERNAL HELPERS
# ==========================================

func _is_playing_action() -> bool:
	if not is_instance_valid(sprite): return false
	var current = sprite.animation
	return sprite.is_playing() and (current.begins_with("attack") or current == "work")


func _animation_finished() -> void:
	if not is_instance_valid(sprite): return
	var current = sprite.animation
	if current.begins_with("attack"):
		attackAnimationFinished.emit()
	elif current == "work":
		interactAnimationFinished.emit()


func cancel_action_state() -> void:
	if is_instance_valid(sprite):
		sprite.stop()
		play_idle()


func _update_damage_visual() -> void:
	if is_instance_valid(sprite):
		var percent: float = float(damageTimer.wait_time - damageTimer.time_left) / damageTimer.wait_time
		sprite.set_instance_shader_parameter(&"progress", percent)


func _on_timer_timeout() -> void:
	if is_instance_valid(sprite):
		sprite.set_instance_shader_parameter(&"progress", 0.0)


func _show_damage() -> void:
	damageTimer.start()


func set_sprite_frames(frames: SpriteFrames) -> void:
	if not is_instance_valid(sprite): return
	if sprite.sprite_frames == frames: return
	sprite.stop()
	sprite.sprite_frames = frames
	_update_move_anim_cache()
	play_idle()


func _update_move_anim_cache() -> void:
	_move_anim = &""
	if not is_instance_valid(sprite) or sprite.sprite_frames == null: return
	if sprite.sprite_frames.has_animation("walk"): _move_anim = &"walk"
	elif sprite.sprite_frames.has_animation("run"): _move_anim = &"run"
