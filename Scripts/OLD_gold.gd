extends StaticBody2D

signal pickedUpIAm

@export var amount: int = 0
@export var hitDetection: Area2D
@export var task: Task
@export var player: int = 0
@export var carry: bool = false
@export var spawn: Spawns
@export var pickedUpBy: Array[String] = []
@export var notPickedUpBy: Array[String] = []

var idle = false
@onready var carried = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(hitDetection):
		hitDetection.body_entered.connect(_body_entered)
	
	$AnimatedSprite2D.play("spawn")
	$SpawnTimer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _body_entered(body: Node2D) -> void:
	var pickup: bool = false
	
	if !carried and $SpawnTimer.is_stopped() and !idle and ((is_instance_valid(task) and task.check_body_no_finish(body)) or body.is_idle()):
		for picked in pickedUpBy:
			if body.is_in_group(picked):
				pickup = true

		for notPicked in notPickedUpBy:
			if body.is_in_group(notPicked):
				pickup = false

	if pickup:
		pickedUpIAm.emit()
		
		if carry:
			carried = true
			body.carry_me(self)
			if is_instance_valid(task):
				task.task_finished()
			body.return_to_castle()

		elif is_instance_valid(body.gold):
			body.gold.pickup_gold(amount)
			if is_instance_valid(task):
				task.check_body(body)
			_idle_me()


func _idle_me() -> void:
	idle = true
	$AnimatedSprite2D.play("idle")
	delete_me()


####
# Called by World Objects.
####
func setup_gold(position: Vector2, goldAmount: int, setPlayer: int) -> void:
	global_position = position
	amount = goldAmount
	player = setPlayer


func return_player() -> int:
	return player


func return_castle() -> Node:
	return null


func return_position() -> Vector2:
	return global_position


func delete_me() -> void:
	if is_instance_valid(task):
		task.task_finished()
	self.queue_free()
