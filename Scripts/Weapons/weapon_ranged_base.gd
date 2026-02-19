extends Node
class_name WeaponRanged

# --- WEAPON STATS ---
@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0
@export_range(0.0, 100.0, 1.0) var base_accuracy: float = 50.0 # New: Base skill (0-100)
@export_range(0.0, 5.0, 0.1) var wind_resistance: float = 1.0 # New: 0.0 = Immune to wind

# --- TARGETING ---
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = false

# --- PROJECTILE SETUP ---
@export var projectile_scene: PackedScene
@export var muzzle: Node3D # Optional spawn point
@export var projectile_parent_path: NodePath
@export var projectile_speed: float = 700.0
@export var attack_power: int = 10
@export var attack_priority: int = 7

# --- REFS ---
@export var movement: AgentMovement = null
@onready var tracking: AgentTracking = $AgentTracking
@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

# --- INTERNAL STATE ---
var _owner_agent: AgentBase = null
var _current_target: AgentBase = null
var _projectile_parent: Node = null
var _attack_paused: bool = false
var _attacking: bool = false

# --- ACCURACY / BUFF STATE ---
var accuracy_modifiers: Array = [] # Stores temporary buffs (floats)


func _ready() -> void:
	# Configure tracking
	tracking.target_kind = AgentTracking.TargetKind.ATTACKABLE
	tracking.target_same_team = affects_own
	tracking.target_opposing = affects_opposing
	tracking.target_neutral = affects_neutral

	tracking.target_changed.connect(_on_target_changed)
	tracking.target_lost.connect(_on_target_lost)

	cooldown.timeout.connect(_try_attack)
	attack_delay.timeout.connect(_on_attack_delay_timeout)

	_projectile_parent = _resolve_projectile_parent()


func set_player(owner_agent: AgentBase) -> void:
	_owner_agent = owner_agent
	tracking.setup_player(owner_agent.player)


# --- CONTROL API ---

func pause_attack(priority: int = 5) -> void:
	_attack_paused = true


func restart_attack(priority: int = 5) -> void:
	_attack_paused = false
	_current_target = tracking.current_target
	_try_attack()

func _cancel_attack() -> void:
	_current_target = null
	
	if movement and _attacking:
		movement.clear_movement_order(attack_priority)

	cooldown.stop()
	attack_delay.stop()
	_attacking = false


# --- TARGETING CALLBACKS ---

func _on_target_changed(t: AgentBase) -> void:
	_current_target = t
	_try_attack()

func _on_target_lost() -> void:
	_cancel_attack()


# --- ATTACK LOGIC ---

func _try_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		_cancel_attack()
		return

	if not cooldown.is_stopped() or not attack_delay.is_stopped():
		return

	if projectile_scene == null:
		return

	if not _attack_paused and movement and movement.command_start_attack(_current_target, attack_priority):
		_attacking = true
		cooldown.start()
		attack_delay.start()
	else:
		_cancel_attack()


func _on_attack_delay_timeout() -> void:
	# 1. Validate Target
	var t := _current_target
	if t == null or not is_instance_valid(t):
		return

	# Ensure target is still a valid candidate (range check, etc)
	# Note: get_candidates() might be expensive to check every shot, 
	# usually relying on tracking signals is enough, but this is safe.
	if not tracking.current_target:
		return

	if projectile_scene == null:
		return
	if not _owner_agent or not _owner_agent.has_method("return_player"):
		return

	# 2. Resolve Parent
	var parent := _projectile_parent
	if parent == null or not is_instance_valid(parent):
		parent = get_tree().current_scene
		_projectile_parent = parent

	# 3. Calculate Spawn & Impact Points
	var spawn_pos := _get_spawn_position()
	
	# [NEW] Calculate the realistic hit position (Accuracy + Wind)
	var impact_point := get_shot_point(spawn_pos, t.global_position)

	# 4. Instantiate Projectile
	var proj := projectile_scene.instantiate()
	parent.add_child(proj)

	# 5. Setup Attack Data
	var atk := AttackData.new()
	atk.attack_power = attack_power
	atk.attacker_player = _owner_agent.return_player()
	atk.attacker = _owner_agent
	atk.source = self

	# 6. Initialize Projectile
	if proj.has_method("init"):
		# We pass 'impact_point' instead of 't.global_position'
		proj.call("init", spawn_pos, impact_point, projectile_speed, atk)
	else:
		push_warning("Projectile does not have function init.")


# --- ACCURACY & WIND MATH ---

func get_current_accuracy() -> float:
	var total = base_accuracy
	for mod in accuracy_modifiers:
		total += mod
	return clamp(total, 0.0, 100.0)


func add_accuracy_buff(amount: float, duration: float) -> void:
	accuracy_modifiers.append(amount)
	# Auto-remove buff after duration
	get_tree().create_timer(duration).timeout.connect(func(): accuracy_modifiers.erase(amount))


func get_shot_point(origin: Vector3, target_pos: Vector3) -> Vector3:
	var dist = origin.distance_to(target_pos)
	
	# 1. Calculate Inaccuracy (Standard Gaussian)
	var acc_score = get_current_accuracy()
	var inaccuracy = (100.0 - acc_score) / 100.0 
	var spread_factor = 0.05 
	var deviation = dist * inaccuracy * spread_factor
	var error_offset = Vector3(randfn(0.0, deviation), randfn(0.0, deviation), 0)

	# 2. Calculate Wind Drift (UPDATED)
	# OLD: Weather.wind_direction * Weather.wind_speed
	# NEW: Weather.current_wind_dir * (Weather.current_wind_speed * FORCE_MULTIPLIER)
	
	# We multiply by 10.0 because the new scale is 0-10, 
	# but we want the wind to push arrows by ~100 pixels in a storm.
	var physics_wind_speed = Weather.current_wind_speed * 10.0 
	
	var wind_push = Weather.current_wind_dir * physics_wind_speed * (dist / 1000.0) * wind_resistance
	
	return target_pos + error_offset + wind_push
	

# --- HELPERS ---

func _get_spawn_position() -> Vector3:
	if muzzle:
		return muzzle.global_position

	if _owner_agent:
		return _owner_agent.global_position

	return Vector3.ZERO


func _resolve_projectile_parent() -> Node:
	if projectile_parent_path != NodePath() and has_node(projectile_parent_path):
		return get_node(projectile_parent_path)

	var scene := get_tree().current_scene
	if scene and scene.has_node("Projectiles"):
		return scene.get_node("Projectiles")

	return scene


func am_i_attacking() -> bool:
	return _attacking

func attack_animation_finished() -> void:
	pass

func set_movement(m: AgentMovement) -> void:
	movement = m
