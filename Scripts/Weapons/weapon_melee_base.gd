extends Node
class_name WeaponMelee

@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0

# Who can this weapon affect?
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = false
@export var attack_power: int = 10

@onready var tracking: AgentTracking = $AgentTracking
@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

var _attacking: bool = false
var team: TeamMemory = null

func _ready() -> void:
	# Configure tracking for attackable targets (capability: health)
	tracking.target_kind = AgentTracking.TargetKind.ATTACKABLE
	tracking.target_same_team = affects_own
	tracking.target_opposing = affects_opposing
	tracking.target_neutral = affects_neutral

	# cooldown.timeout.connect(_try_attack)
	attack_delay.timeout.connect(_on_attack_delay_timeout)
	
	# Establish connection to TeamMemory.
	team = ComponentFinder.get_component(self, "TeamMemory")
	if team and not team.team_changed.is_connected(_team_changed):
		team.team_changed.connect(_team_changed)
	_team_changed(team.return_team())


func _team_changed(new_team: int) -> void:
	tracking.setup_player(new_team)


func _cancel_attack() -> void:
	cooldown.stop()
	attack_delay.stop()
	_attacking = false


# --- API FOR ADVISOR ---

func is_target_in_range(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	# Check if target is in our tracking candidates (implies range/validity)
	var candidates = tracking.get_candidates()
	return target in candidates


func perform_attack_tick(target: AgentBase) -> bool:
	if not is_instance_valid(target):
		_cancel_attack()
		return false

	if not cooldown.is_stopped() or not attack_delay.is_stopped():
		return false

	# We assume movement is already handled by Brain
	_attacking = true
	cooldown.start()
	attack_delay.start()

	# We need to store the target for the delay callback
	# But careful about storing it if we want to be stateless.
	# However, for delay callback we need it.
	_temp_target = target
	return true


var _temp_target: AgentBase = null


func _on_attack_delay_timeout() -> void:
	var t := _temp_target
	if t == null or not is_instance_valid(t):
		return

	# Ensure target is still in range?
	if not is_target_in_range(t):
		return

	var h: Health = t.get("health")
	if not is_instance_valid(h):
		return

	var atk := AttackData.new()
	atk.attack_power = attack_power
	atk.attacker_player = team.return_team()
	atk.attacker = ComponentFinder.get_base(self)
	atk.source = self

	h.apply_hit(atk)


func am_i_attacking() -> bool:
	return _attacking or not cooldown.is_stopped()
