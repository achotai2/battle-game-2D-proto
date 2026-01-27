extends StaticBody2D

@export var player: int = 0
@export var worker_job_board: CastleJobBoard
@export var peasant_job_board: CastleJobBoard
@export var food_job_board: CastleJobBoard

var _sheep: Array[Node2D]


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


func register_sheep(new_sheep: Node2D) -> void:
	if new_sheep in _sheep:
		return

	_sheep.append(new_sheep)


func unregister_sheep(old_sheep: Node2D) -> void:
	var idx := _sheep.find(old_sheep)
	if idx != -1:
		_sheep.remove_at(idx)


func get_nearest(type: StringName, pos: Vector2) -> Node2D:
	var _to_return: Node2D = null

	if type == &"sheep":
		for s in _sheep:
			if _to_return == null or pos.distance_to(s.global_position) < pos.distance_to(_to_return.global_position):
				_to_return = s

	return _to_return
