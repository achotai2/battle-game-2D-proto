extends Node
class_name TacticalLord

@export var tax_check_interval: float = 1.0
@export var movement: AgentMovement = null

var _tax_timer: Timer


func _ready() -> void:
	_tax_timer = Timer.new()
	_tax_timer.wait_time = tax_check_interval
	_tax_timer.one_shot = false
	_tax_timer.timeout.connect(_on_tax_check)
	add_child(_tax_timer)
	_tax_timer.start(randf())


# Standard Tactical Interface (required by AgentBase but maybe unused by Lord)
func set_target(t: AgentBase) -> void:
	pass


func set_agent(t: AgentBase) -> void:
	pass


func set_movement(m: AgentMovement) -> void:
	pass


func _on_tax_check() -> void:
	# Get list of minions from castle.
	if is_instance_valid(get_parent().castle):
		var _minions: Array = get_parent().castle.get_active_minions()
	
		for m in _minions:
			if is_instance_valid(m.gold):
				m.gold.can_i_tax_you(get_parent())
