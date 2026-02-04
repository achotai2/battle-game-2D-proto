extends StaticBody2D

@export var player: int = 0
@export var worker_job_board: CastleJobBoard
@export var peasant_job_board: CastleJobBoard
@export var food_job_board: CastleJobBoard

var minions: Array[Node2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func return_job_board(kind: CastleJobBoard.JobBoardType) -> CastleJobBoard:
	if kind == CastleJobBoard.JobBoardType.WORKERS:
		return worker_job_board
	elif kind ==  CastleJobBoard.JobBoardType.PEASANTS:
		return peasant_job_board
	elif kind ==  CastleJobBoard.JobBoardType.FOOD:
		return food_job_board
	else:
		return null


func register_minion(minion: Node2D) -> void:
	if not minion in minions:
		minions.append(minion) 


func unregister_minion(minion: Node2D) -> void:
	if minion in minions:
		minions.erase(minion)


func get_active_minions() -> Array:
	return minions
