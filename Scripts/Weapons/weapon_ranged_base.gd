extends Node3D
class_name WeaponRanged

# --- WEAPON STATS ---
@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0
@export var attack_range: float = 15.0 
@export_range(0.0, 100.0, 1.0) var base_accuracy: float = 50.0 
@export_range(0.0, 5.0, 0.1) var wind_resistance: float = 1.0 

# --- TARGETING ---
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = true

# --- PROJECTILE SETUP ---
@export var projectile_scene: PackedScene
@export var muzzle: Node3D 
@export var projectile_parent_path: NodePath
@export var projectile_speed: float = 10.0
@export var attack_power: int = 10

# --- REFS ---
@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

# --- INTERNAL STATE ---
var _projectile_parent: Node = null
var _attacking: bool = false
var _temp_target: Node3D = null

var _my_base: Node3D = null
var _my_team = null

# --- ACCURACY / BUFF STATE ---
var accuracy_modifiers: Array = [] 


func _ready() -> void:
	attack_delay.timeout.connect(_on_attack_delay_timeout)
	_projectile_parent = _resolve_projectile_parent()

	# 1. Traverse up the tree to find the root AgentBase or BuildingBase
	_my_base = _find_root_base(self)

	# 2. Directly grab the team variable from the root node
	if is_instance_valid(_my_base):
		_my_team = _my_base.get("team")
		if not _my_team:
			_my_team = _my_base.get("team_memory")


func _cancel_attack() -> void:
	cooldown.stop()
	attack_delay.stop()
	_attacking = false
	_temp_target = null


# --- API FOR ADVISOR ---

func is_target_in_range(target: Node3D) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(_my_base): 
		return false
		
	var dist = _my_base.global_position.distance_to(target.global_position)
	return dist <= attack_range


func perform_attack_tick(target: Node3D) -> bool:
	if not is_instance_valid(target):
		_cancel_attack()
		return false

	if not cooldown.is_stopped() or not attack_delay.is_stopped():
		return false

	if projectile_scene == null:
		return false

	_attacking = true
	cooldown.start()
	attack_delay.start()
	_temp_target = target
	return true


func _on_attack_delay_timeout() -> void:
	var t := _temp_target
	if t == null or not is_instance_valid(t):
		return

	if not is_target_in_range(t):
		return

	if projectile_scene == null:
		return

	var parent := _projectile_parent
	if parent == null or not is_instance_valid(parent):
		parent = get_tree().current_scene
		_projectile_parent = parent

	var spawn_pos := _get_spawn_position(_my_base)
	var impact_point := get_shot_point(spawn_pos, t.global_position)

	var proj := projectile_scene.instantiate()
	parent.add_child(proj)

	var atk := AttackData.new()
	atk.attack_power = attack_power
	
	if is_instance_valid(_my_team) and _my_team.has_method("return_team"):
		atk.attacker_player = _my_team.return_team()
	else:
		atk.attacker_player = 0
		
	atk.attacker = _my_base
	atk.source = self

	if proj.has_method("init"):
		proj.call("init", spawn_pos, impact_point, projectile_speed, atk)
	else:
		push_warning("Projectile does not have function init.")

	_temp_target = null


# --- ACCURACY & WIND MATH ---

func get_current_accuracy() -> float:
	var total = base_accuracy
	for mod in accuracy_modifiers:
		total += mod
	return clamp(total, 0.0, 100.0)


func get_shot_point(origin: Vector3, target_pos: Vector3) -> Vector3:
	var dist = origin.distance_to(target_pos)
	
	var acc_score = get_current_accuracy()
	var inaccuracy = (100.0 - acc_score) / 100.0 
	var spread_factor = 0.05 
	var deviation = dist * inaccuracy * spread_factor
	
	var error_offset = Vector3(randfn(0.0, deviation), 0, randfn(0.0, deviation))

	var physics_wind_speed = 0.0
	var wind_push = Vector3.ZERO
	if Engine.has_singleton("Weather") or get_tree().root.has_node("Weather"):
		physics_wind_speed = Weather.current_wind_speed * 10.0 
		wind_push = Weather.current_wind_dir * physics_wind_speed * (dist / 1000.0) * wind_resistance
	
	return target_pos + error_offset + wind_push


# --- HELPERS ---

func _get_spawn_position(boss: Node) -> Vector3:
	if muzzle:
		return muzzle.global_position
	if is_instance_valid(boss):
		return boss.global_position + Vector3(0, 1.0, 0)
	return global_position


func _resolve_projectile_parent() -> Node:
	if projectile_parent_path != NodePath() and has_node(projectile_parent_path):
		return get_node(projectile_parent_path)

	var scene := get_tree().current_scene
	if scene and scene.has_node("Projectiles"):
		return scene.get_node("Projectiles")

	return scene

func am_i_attacking() -> bool:
	return _attacking or not cooldown.is_stopped()


# A safe replacement for ComponentFinder.get_base()
func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase or current.has_method("return_castle"): # Checking for Agent or Building
			return current as Node3D
		current = current.get_parent()
	return null
