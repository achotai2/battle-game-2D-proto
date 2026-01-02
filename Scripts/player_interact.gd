extends Node
class_name PlayerInteract

signal noInteractTarget

var target: Node
var myPlayer: int


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
#	$AgentTracking.foundTarget.connect(_new_target)
#	$AgentTracking.noTarget.connect(_no_target)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _new_target() -> void:
	if target and target.interact:
		target.interact.is_not_target(self)
	if $AgentTracking.return_targets().size() > 0:
		target = $AgentTracking.return_targets()[0]
	else:
		target = null

	if target and target.interact:
		target.interact.is_target(self)


func _no_target() -> void:
	if target and target.interact:
		target.interact.is_not_target(self)
	target = null

####
# External functions called from Player
####
func set_player(myParent: Node2D, player: int) -> void:
	myPlayer = player
	$AgentTracking.set_myself(myParent, player)
	#$AgentTracking.set_target_type(true, true, false)


func interaction_engaged() -> void:
	if target and target.interact:
		target.interact.started(self)
		$AgentTracking.stop_timer() # So that the target doesn't update mid interaction.

func interaction_released() -> void:
	pass
