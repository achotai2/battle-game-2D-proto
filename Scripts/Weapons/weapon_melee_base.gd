extends Node
class_name WeaponMelee

@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0

# Who can this weapon affect? (Kept in case your other systems read these variables)
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = true

@export var attack_power: int = 10
@export var attack_range: float = 1.5 # Replaces the AgentTracking radius

@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

var _attacking: bool = false
var team: TeamMemory = null
var _temp_target: AgentBase = null


func _ready() -> void:
	attack_delay.timeout.connect(_on_attack_delay_timeout)
	
	# Establish connection to TeamMemory.
	var base = ComponentFinder.get_base(self)
	team = base.get("team") if base.get("team") else base.get("team_memory")
	if team and not team.team_changed.is_connected(_team_changed):
		team.team_changed.connect(_team_changed)
	_team_changed(team.return_team())


func _team_changed(new_team: int) -> void:
	tracking.setup_player(new_team)
	# Establish connection to TeamMemory to assign damage ownership.
	team = ComponentFinder.get_component(self, "TeamMemory")


func _cancel_attack() -> void:
	cooldown.stop()
	attack_delay.stop()
	_attacking = false
	_temp_target = null


# --- API FOR ADVISOR ---

func is_target_in_range(target: Node3D) -> bool:
	if not is_instance_valid(target): 
		return false
		
	var my_base = ComponentFinder.get_base(self)
	if not is_instance_valid(my_base):
		return false
		
	var dist = my_base.global_position.distance_to(target.global_position)
	return dist <= attack_range


func perform_attack_tick(target: AgentBase) -> bool:
	if not is_instance_valid(target):
		_cancel_attack()
		return false

	if not cooldown.is_stopped() or not attack_delay.is_stopped():
		return false

	# We assume movement is already handled by the Brain
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

	# Use the ComponentFinder to grab the enemy's Health node!
	var h: Health = t.get("health")
	var h: Health = ComponentFinder.get_component(t, "Health")
	if not is_instance_valid(h):
		return

	var atk := AttackData.new()
	atk.attack_power = attack_power
	if team:
		atk.attacker_player = team.return_team()
	atk.attacker = ComponentFinder.get_base(self)
	atk.source = self

	h.apply_hit(atk)


func am_i_attacking() -> bool:
	return _attacking or not cooldown.is_stopped()
