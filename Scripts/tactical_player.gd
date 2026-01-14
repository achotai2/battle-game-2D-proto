extends Node
class_name TacticalPlayer

var _player_controls_activated: bool = false
var _agent: Node2D = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func player_movement_activated(dir: Vector2) -> void:
	# Tell attack to stop attacking if moving, or restart attacking if not moving. Called from player controls node.
	if dir == Vector2.ZERO:
		player_controls_deactivated()
	else:
		player_controls_activated()


func player_controls_activated() -> void:
	_player_controls_activated = true

	if is_instance_valid(_agent) and is_instance_valid(_agent.attack):
		_agent.attack.stop_delay_timer()


func player_controls_deactivated() -> void:
	_player_controls_activated = false
	# Restart attack and check if target in range.
	
	if is_instance_valid(_agent) and is_instance_valid(_agent.attack):
		_agent.attack.restart_attack()


func set_agent(my_agent: Node2D) -> void:
	_agent = my_agent


func attack_finished() -> void:
	# Called by signal from animation when attack animation finishes.
	if is_instance_valid(_agent) and is_instance_valid(_agent.movement):
		_agent.movement.un_freeze()
