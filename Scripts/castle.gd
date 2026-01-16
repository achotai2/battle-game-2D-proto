extends StaticBody2D

@export var player: int = 0
@export var worker_job_board: CastleJobBoard

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func return_job_board() -> CastleJobBoard:
	if is_instance_valid(worker_job_board):
		return worker_job_board
	else:
		return null
