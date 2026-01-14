extends Node
class_name SheepBase

@export var gold: Node
@export var animation: AgentAnimate
@export var sheepTask: Task
@export var workerTask: Task
@export var breedingAmount: int
@export var deathAmount: int

var targetable: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_instance_valid(gold):
		gold.updateGold.connect(_new_gold)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _new_gold(amount: int) -> void:
	if amount > breedingAmount:
		sheepTask.need_task()

	if amount >= deathAmount:
		targetable = true
		workerTask.need_task()


####
# Called by hammer weapon, since sheep go from not targetable to is.
####
func can_target() -> bool:
	return targetable
