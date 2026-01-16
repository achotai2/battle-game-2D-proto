extends Node
class_name WeaponMelee

@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 0

# Who can this weapon affect?
@export var affects_own: bool = false
@export var affects_opposing: bool = true
@export var affects_neutral: bool = false
@export var attack_power: int = 10
@export var animation: AgentAnimate = null
@export var movement: AgentMovement = null

@onready var tracking: AgentTracking = $AgentTracking
@onready var cooldown: Timer = $cooldown
@onready var attack_delay: Timer = $AttackDelay

var _owner_agent: Node
var _current_target: Node2D = null
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


func set_player(owner_agent: Node2D) -> void:
	_owner_agent = owner_agent
	tracking.set_myself(owner_agent)


func pause_attack() -> void:
	# Called by controls player node
	_attack_paused = true
	cooldown.stop()
	attack_delay.stop() # prevent firing while player is moving


func restart_attack() -> void:
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

	cooldown.start()
	attack_delay.start()
	if is_instance_valid(movement):
		movement.start_attack(_current_target)
	elif is_instance_valid(animation):
		animation.play_attack(_current_target)


func _on_attack_delay_timeout() -> void:
	# Single-target strike: apply to the chosen target if still valid and still in range.
	var t := _current_target
	if t == null or not is_instance_valid(t):
		return

	# Ensure the target is still within tracking range (still a candidate)
	if not tracking.get_candidates().has(t):
		return

	# Capability reference stored on the target's main script
	var h: Health = t.get("health")
	if not is_instance_valid(h):
		return
	if not is_instance_valid(_owner_agent) or not _owner_agent.has_method("return_player"):
		return

	var atk := AttackData.new()
	atk.attack_power = attack_power
	atk.attacker_player = _owner_agent.return_player()
	atk.attacker = _owner_agent
	atk.source = self

	h.apply_hit(atk)


func attack_animation_finished() -> void:
	if is_instance_valid(movement):
		movement.unfreeze(AgentMovement.LOCK_ATTACK)
