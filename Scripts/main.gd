extends Node3D

var playerOneTarget: Node
var playerTwoTarget: Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
#	$Objects.updateGold.connect(_update_gold_label)

#	_update_gold_label($Objects.get_player_gold_amount())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("click"):
		_change_minion()


func _update_gold_label(gold: int) -> void:
	$CanvasLayer/Label.text = "Gold: " + str(gold)


func _change_minion() -> void:
#	$Units/Soldier.apply_role('peasant', 2)
	pass
