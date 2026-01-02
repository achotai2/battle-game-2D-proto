extends Node

@export var myAgent: CharacterBody2D
@export var animation: AgentAnimate
@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 1000, 1) var heal: int = 10
## Does this weapon target my own units? If false then _strike will repair with negative damage instead.
@export var damagesOwn: bool = false
## Does this weapon target opposing units?
@export var damagesOpposing: bool = true
## Does this weapon target neutral units?
@export var damagesNeutral: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if $AgentTracking:
		$AgentTracking.foundTarget.connect(_new_target)
	if $cooldown:
		$cooldown.timeout.connect(_on_cooldown_finished)
	if $AttackDelay:
		$AttackDelay.timeout.connect(_on_attack_delay_timeout)
		
	call_deferred("_connect_myAgent")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	$AgentTracking.position = get_parent().global_position


func _strike() -> void:
	if $cooldown.is_stopped():
		var targets: Array
		if $AgentTracking.has_target():
			targets = $AgentTracking.return_targets()
		if _target_for_damage(targets) or _target_for_heal(targets):
			$cooldown.start()
			$AttackDelay.start()
			
			if is_instance_valid(animation):
				animation.play_attack(targets[0])


func _new_target() -> void:
	_strike()


func _on_cooldown_finished() -> void:
	_strike()


func _on_attack_delay_timeout() -> void:
	var targets: Array = $AgentTracking.return_targets()
	if $AgentTracking.has_target():
		var targetForHeal: Node = _target_for_heal(targets)
		var targetForDamage: Node = _target_for_damage(targets)
		if is_instance_valid(targetForHeal):
			targetForHeal.health.take_damage(-heal, myAgent.return_player()) 
		elif is_instance_valid(targetForDamage):
			targetForDamage.health.take_damage(damage, myAgent.return_player()) 


func _target_for_damage(targets: Array) -> Node:
	for target in targets:
		if is_instance_valid(target.health):
			if target.return_player() != myAgent.return_player() and target.return_player() != 0:
				return target
			elif target.is_in_group("Sheeps") and is_instance_valid(target.base) and target.base.can_target():
				return target

	return null


func _target_for_heal(targets: Array) -> Node:
	for target in targets:
		if is_instance_valid(target.health):
			if target.is_in_group("Buildings") and target.return_player() == myAgent.return_player() and !target.health.is_max_health():
				return target
			elif target.is_in_group("Trees") and !target.health.is_max_health():
				return target

	return null


func _connect_myAgent() -> void:
	if is_instance_valid(myAgent):
		myAgent.playerUpdate.connect(_set_player)
	_set_player(myAgent.return_player())


func _set_player(player: int) -> void:
	# Which players entities this weapon effects.
	$AgentTracking.set_myself(myAgent, player)


####
# External functions called by agent
####
func return_damage() -> int:
	return damage


func has_target() -> bool:
	return true if $AgentTracking.return_targets().size() > 0 else false
