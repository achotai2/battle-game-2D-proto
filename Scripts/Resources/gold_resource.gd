extends Node3D
class_name GoldResource

@export var killMeTimer: Timer = null
@export var _sprite: AnimatedSprite3D = null
@export var fly_speed: float = 6.0
@export var hover_duration: float = 0.5

var _target: Node3D = null
var _arrived: bool = false
var _hover_time: float = 0.0
var _hover_start_y: float = 0.0


func _ready() -> void:
	if is_instance_valid(_sprite):
		_sprite.play("spawn")


func on_create(initial_pos: Vector3, target_node: Node3D) -> void:
	global_position = initial_pos
	_target = target_node


func _process(delta: float) -> void:
	# If the target died or vanished while we were flying, just stop and hover here!
	if not is_instance_valid(_target):
		if not _arrived:
			_start_hover()
		_process_hover(delta)
		return

	if not _arrived:
		# Aim slightly above the target's feet so it hits their chest/head
		var target_pos = _target.global_position + Vector3(0, 1.0, 0)
		
		# Check how close we are
		var distance = global_position.distance_to(target_pos)
		
		if distance < 0.2:
			_start_hover()
		else:
			# Fly towards the target!
			var direction = global_position.direction_to(target_pos)
			global_position += direction * fly_speed * delta
	else:
		_process_hover(delta)


func _start_hover() -> void:
	_arrived = true
	_hover_start_y = global_position.y
	
	if is_instance_valid(killMeTimer):
		# Override the wait time in code just in case the inspector is set too high
		killMeTimer.start(hover_duration) 
	else:
		# Fallback if you forgot to assign the timer in the inspector
		await get_tree().create_timer(hover_duration).timeout
		queue_free()


func _process_hover(delta: float) -> void:
	# Add a gentle sine wave to make it bob up and down while it waits to disappear
	_hover_time += delta
	global_position.y = _hover_start_y + (sin(_hover_time * 8.0) * 0.15)


func _on_kill_me_timer_timeout() -> void:
	queue_free()
