extends Node
class_name AgentMovement

signal iMoved(velocity: Vector2)

@export_range(0, 500, 10) var max_speed: float = 300.0
@export_range(0, 500, 10) var meander_speed: float = 50.0

@export var frozen: bool = false
@export var can_meander: bool = false
var meander: bool = false

# Optional smoothing (helps crowd jitter)
@export_range(0.0, 200.0, 0.5) var accel: float = 0.0

var _current_velocity: Vector2 = Vector2.ZERO


# --- Public control API ---

func freeze() -> void:
	frozen = true
	_current_velocity = Vector2.ZERO
	iMoved.emit(Vector2.ZERO)

func un_freeze() -> void:
	frozen = false

func make_meander() -> void:
	if can_meander:
		meander = true

func stop_meander() -> void:
	meander = false


# --- Movement entry points (called by Agent) ---

# Preferred: already-scaled velocity (pathfinding + avoidance)
func move_with_velocity(desired_velocity: Vector2, delta: float) -> void:
	if frozen:
		_current_velocity = Vector2.ZERO
		iMoved.emit(Vector2.ZERO)
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

	iMoved.emit(_current_velocity)


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
