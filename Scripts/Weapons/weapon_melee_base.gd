extends Node
class_name WeaponMelee

@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0

# Who can this weapon affect? 
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = true

@export var attack_power: int = 10
@export var attack_range: float = 1.5 

@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

var _attacking: bool = false
var _temp_target: AgentBase = null

var _my_base: Node3D = null
var _my_team = null


func _ready() -> void:
	pass

func deactivate() -> void:
	if cooldown: cooldown.stop()
	if attack_delay: attack_delay.stop()
	_cancel_attack()

func activate() -> void:
	if not attack_delay.timeout.is_connected(_on_attack_delay_timeout):
		attack_delay.timeout.connect(_on_attack_delay_timeout)
	
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


func perform_attack_tick(target: AgentBase) -> bool:
	if not is_instance_valid(target):
		_cancel_attack()
		return false

	if not cooldown.is_stopped() or not attack_delay.is_stopped():
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

	# 3. Directly reference the target's health variable!
	var h = t.get("health")
	if not is_instance_valid(h):
		return

	var atk := AttackData.new()
	atk.attack_power = attack_power
	
	if is_instance_valid(_my_team) and _my_team.has_method("return_team"):
		atk.attacker_player = _my_team.return_team()
		
	atk.attacker = _my_base
	atk.source = self

	if h.has_method("apply_hit"):
		h.apply_hit(atk)


func am_i_attacking() -> bool:
	return _attacking or not cooldown.is_stopped()


# --- HELPERS ---

# A safe replacement for ComponentFinder.get_base()
func _find_root_base(start_node: Node) -> Node3D:
	var current = start_node
	while current and current != get_tree().root:
		if current is AgentBase or current.has_method("return_castle"): # Checking for Agent or Building
			return current as Node3D
		current = current.get_parent()
	return null
