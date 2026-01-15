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


func _physics_process(delta: float) -> void:
	# Convert intent -> movement with the correct delta
	if _use_velocity:
		move_with_velocity(_desired_velocity, delta)
	else:
		move_in_direction(_desired_direction, delta)


# --- Public control API ---

func freeze(_target: Node2D) -> void:
	# Called by attack when attack is started
	frozen = true
	_current_velocity = Vector2.ZERO
	_notify_moved(Vector2.ZERO)


func un_freeze() -> void:
	# Called to unfreeze movement.
	# Can be called by signal from agent animation when a frozen animation is finished.
	frozen = false


func make_meander() -> void:
	if can_meander:
		meander = true

func stop_meander() -> void:
	meander = false


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


func _notify_moved(vel: Vector2) -> void:
	if is_instance_valid(agent):
		agent.velocity = vel

	if is_instance_valid(animation):
		animation.agent_moved(vel)
