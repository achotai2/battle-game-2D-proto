extends Node
class_name AgentMovement

@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0

@export var frozen: bool = false
@export var can_meander: bool = false
@export var agent: Node2D = null
@export var animation: AgentAnimate = null
var meander: bool = false

# Optional smoothing (helps crowd jitter)
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

var _current_velocity: Vector2 = Vector2.ZERO
var _use_velocity: bool
var _desired_velocity: Vector2
var _desired_direction: Vector2
var _action_state: int = 0

const ACTION_NONE := 0
const ACTION_ATTACK := 1
const ACTION_WORK := 2
const ACTION_INTERACT := 3


func _physics_process(delta: float) -> void:
	# Convert intent -> movement with the correct delta
	if _use_velocity:
		move_with_velocity(_desired_velocity, delta)
	else:
		move_in_direction(_desired_direction, delta)


# --- Public control API ---

func set_animation(anim: AgentAnimate) -> void:
	if is_instance_valid(animation):
		if animation.attackAnimationFinished.is_connected(_on_attack_animation_finished):
			animation.attackAnimationFinished.disconnect(_on_attack_animation_finished)
		if animation.interactAnimationFinished.is_connected(_on_interact_animation_finished):
			animation.interactAnimationFinished.disconnect(_on_interact_animation_finished)

	animation = anim

	if is_instance_valid(animation):
		if not animation.attackAnimationFinished.is_connected(_on_attack_animation_finished):
			animation.attackAnimationFinished.connect(_on_attack_animation_finished)
		if not animation.interactAnimationFinished.is_connected(_on_interact_animation_finished):
			animation.interactAnimationFinished.connect(_on_interact_animation_finished)


func freeze(_target: Node2D) -> void:
	# Called by attack when attack is started
	frozen = true
	_current_velocity = Vector2.ZERO
	_notify_moved(Vector2.ZERO)


func un_freeze() -> void:
	# Called to unfreeze movement.
	# Can be called by signal from agent animation when a frozen animation is finished.
	frozen = false
	_action_state = ACTION_NONE


func make_meander() -> void:
	if can_meander:
		meander = true

func stop_meander() -> void:
	meander = false


func start_attack(target: Node2D) -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_ATTACK:
		return false
	if _action_state == ACTION_ATTACK and frozen:
		return true

	_action_state = ACTION_ATTACK
	freeze(target)
	var started := false
	if is_instance_valid(animation):
		started = animation.play_attack(target)

	if not started:
		un_freeze()
	return started


func start_work() -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_WORK:
		return false
	if _action_state == ACTION_WORK and frozen:
		return true

	_action_state = ACTION_WORK
	freeze(null)
	var started := false
	if is_instance_valid(animation):
		started = animation.play_work()

	if not started:
		un_freeze()
	return started


func start_interaction() -> bool:
	if _action_state != ACTION_NONE and _action_state != ACTION_INTERACT:
		return false
	if _action_state == ACTION_INTERACT and frozen:
		return true

	_action_state = ACTION_INTERACT
	freeze(null)
	var started := false
	if is_instance_valid(animation):
		started = animation.play_work()

	if not started:
		un_freeze()
	return started


# --- Movement entry points ---

# Preferred: already-scaled velocity (pathfinding + avoidance)
func move_with_velocity(desired_velocity: Vector2, delta: float) -> void:
	if frozen:
		_current_velocity = Vector2.ZERO
		_notify_moved(Vector2.ZERO)
		return

	var speed_cap := meander_speed if meander else max_speed
	var v := desired_velocity

	# Clamp to current speed cap
	var len := v.length()
	if len > speed_cap:
		v = v * (speed_cap / len)

	# Optional acceleration smoothing
	if accel > 0.0 and delta > 0.0:
		_current_velocity = _current_velocity.move_toward(v, accel * delta)
	else:
		_current_velocity = v

	_notify_moved(_current_velocity)


func on_pf_desired_velocity(v: Vector2) -> void:
	# Called on signal from pathfinding.
	_desired_velocity = v  # store as intent
	_use_velocity = true


func player_controlled_movement(dir: Vector2) -> void:
	# Called by controls when movement keys pressed.
	_desired_direction = dir
	_use_velocity = false


# Convenience: direction in (unit or not)
func move_in_direction(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		move_with_velocity(Vector2.ZERO, delta)
	else:
		move_with_velocity(direction.normalized() * max_speed, delta)


func return_speed() -> float:
	if meander:
		return meander_speed
	else:
		return max_speed


func set_my_agent(owner_agent: Node2D) -> void:
	agent = owner_agent


func _on_attack_animation_finished() -> void:
	if _action_state == ACTION_ATTACK:
		un_freeze()


func _on_interact_animation_finished() -> void:
	if _action_state == ACTION_WORK or _action_state == ACTION_INTERACT:
		un_freeze()


func _notify_moved(vel: Vector2) -> void:
	if is_instance_valid(agent):
		agent.velocity = vel

	if is_instance_valid(animation):
		animation.agent_moved(vel)
