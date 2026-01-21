extends Node
class_name WeaponRanged

@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0

# Who can this weapon affect?
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = false

# Projectile setup
@export var projectile_scene: PackedScene
@export var muzzle: Node2D                      # optional spawn point (e.g. "Muzzle" Node2D)
@export var projectile_parent_path: NodePath = ^"/root/main/Projectiles"
# Tip: set this in the inspector to point at your Projectiles node.
# If it's invalid, we will fall back to current_scene.
@export var projectile_speed: float = 700.0
@export var attack_power: int = 10
@export var animation: AgentAnimate = null
@export var movement: AgentMovement = null

@onready var tracking: AgentTracking = $AgentTracking
@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

var _owner_agent: Node2D = null
var _current_target: Node2D = null
var _projectile_parent: Node = null
var _attack_paused: bool = false


func _ready() -> void:
	# Configure tracking for attackable targets (capability: health)
	tracking.target_kind = AgentTracking.TargetKind.ATTACKABLE
	tracking.target_same_team = affects_own
	tracking.target_opposing = affects_opposing
	tracking.target_neutral = affects_neutral

	tracking.target_changed.connect(_on_target_changed)
	tracking.target_lost.connect(_on_target_lost)

	cooldown.timeout.connect(_try_attack)
	attack_delay.timeout.connect(_on_attack_delay_timeout)

	_projectile_parent = _resolve_projectile_parent()


func set_player(owner_agent: Node2D) -> void:
	_owner_agent = owner_agent
	tracking.set_myself(owner_agent)


func pause_attack() -> void:
	# Called by tactical player node
	_attack_paused = true
	cooldown.stop()
	attack_delay.stop() # prevent firing while player is moving


func restart_attack() -> void:
	# Called by tactical player node
	_attack_paused = false
	if _current_target == null and tracking.get_target():
		_current_target = tracking.get_target()
	_try_attack()


func _on_target_changed(t: Node2D) -> void:
	_current_target = t
	_try_attack()


func _on_target_lost() -> void:
	_current_target = null


func _try_attack() -> void:
	if _attack_paused:
		return
	if _current_target == null:
		return
	if not is_instance_valid(_current_target):
		_current_target = null
		return
	if not cooldown.is_stopped():
		return
	if not attack_delay.is_stopped():
		return

	# Optional: only fire if we have a projectile scene
	if projectile_scene == null:
		return

	cooldown.start()
	attack_delay.start()
	if is_instance_valid(movement):
		movement.start_attack(_current_target)
	elif is_instance_valid(animation):
		animation.play_attack(_current_target)


func _on_attack_delay_timeout() -> void:
	if is_instance_valid(movement):
		movement.unfreeze(AgentMovement.LOCK_ATTACK)

	# Spawn a single projectile at the chosen target if still valid and still in range.
	var t := _current_target
	if t == null or not is_instance_valid(t):
		return

	# Ensure the target is still within weapon range (still a candidate)
	if not tracking.get_candidates().has(t):
		return

	if projectile_scene == null:
		return
	if not is_instance_valid(_owner_agent) or not _owner_agent.has_method("return_player"):
		return

	var parent := _projectile_parent
	if parent == null or not is_instance_valid(parent):
		parent = get_tree().current_scene
		_projectile_parent = parent

	var spawn_pos := _get_spawn_position()
	var target_pos := t.global_position
	var dir := (target_pos - spawn_pos)
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var proj := projectile_scene.instantiate()
	parent.add_child(proj)

	# Preferred: projectile has init() / setup() function
	# Supports different projectile scenes with different scripts.
	var atk := AttackData.new()
	atk.attack_power = attack_power
	atk.attacker_player = _owner_agent.return_player()
	atk.attacker = _owner_agent
	atk.source = self

	proj.call("init", spawn_pos, t.global_position, projectile_speed, atk)


func _get_spawn_position() -> Vector2:
	if is_instance_valid(muzzle):
		return muzzle.global_position

	if is_instance_valid(_owner_agent):
		return _owner_agent.global_position

	# Should never happen, but be safe
	push_warning("WeaponRanged has no owner agent or muzzle")
	return Vector2.ZERO


func _resolve_projectile_parent() -> Node:
	# If you set projectile_parent_path in the inspector, we try that first.
	if projectile_parent_path != NodePath() and has_node(projectile_parent_path):
		return get_node(projectile_parent_path)

	# If you prefer, you can also just name the node "Projectiles" under current_scene:
	var scene := get_tree().current_scene
	if scene and scene.has_node("Projectiles"):
		return scene.get_node("Projectiles")

	return scene


func attack_animation_finished() -> void:
	if is_instance_valid(movement):
		movement.unfreeze(AgentMovement.LOCK_ATTACK)
