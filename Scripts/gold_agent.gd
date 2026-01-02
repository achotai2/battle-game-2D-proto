extends Node
class_name GoldAgent

signal updateGold(amount: int)

@export var myAgent: CharacterBody2D
@export var movement: AgentMovement
@export var gold: int
@export var spawns: Spawns
@export var hitDetection: Area2D
@export var timeDropGold: float = 1
@export var doDropGold: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(hitDetection):
		hitDetection.body_entered.connect(_body_entered)
		hitDetection.body_exited.connect(_body_exited)

	$DropTimer.wait_time = timeDropGold
	
	call_deferred("_connect_objects")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _body_entered(body: Node2D) -> void:
	if doDropGold and body.is_in_group("Player") and body.return_player() == myAgent.return_player() and gold > 0:
		$DropTimer.start()
		if is_instance_valid(movement):
			movement.freeze()


func _body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.return_player() == myAgent.return_player():
		$DropTimer.stop()
		if is_instance_valid(movement):
			movement.un_freeze()


func _on_drop_timer_timeout() -> void:
	if doDropGold:
		drop_gold(gold)
		if is_instance_valid(movement):
			movement.un_freeze()


func _connect_objects() -> void:
	var objectsNode = get_tree().get_first_node_in_group("Objects")
	if myAgent.is_in_group("Player"):
		objectsNode.connect_gold(self)


func pickup_gold(amount: int) -> void:
	gold += amount
	updateGold.emit(gold)


func return_gold() -> int:
	return gold


func drop_gold(amount: int) -> void:
	if gold > 0 and is_instance_valid(spawns):
		gold -= amount
		updateGold.emit(gold)
		spawns.spawn_resource(amount)


func has_enough(amount: int) -> bool:
	if return_gold() >= amount:
		return true
	else:
		return false
