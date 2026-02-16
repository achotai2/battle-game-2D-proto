extends StaticBody2D
class_name Castle

@export var player: int = 0
@export var worker_job_board: CastleJobBoard
@export var food_job_board: CastleJobBoard

var minions: Dictionary = {}


func return_job_board(kind: CastleJobBoard.JobBoardType) -> CastleJobBoard:
	if kind == CastleJobBoard.JobBoardType.WORKERS:
		return worker_job_board
	elif kind ==  CastleJobBoard.JobBoardType.FOOD:
		return food_job_board
	else:
		return null


func register_minion(minion: CharacterBody2D) -> void:
	if not minions.has(minion):
		minions[minion] = true


func unregister_minion(minion: CharacterBody2D) -> void:
	minions.erase(minion)


func get_active_minions() -> Array:
	return minions.keys()
