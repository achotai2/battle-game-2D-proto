extends Node

signal spawnMinion(player: int, castle: Node, position: Vector2, type: String)
signal newConstructionTask(building: Node)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		child.spawnMinion.connect(_spawn_minion) 
		child.needsConstruction.connect(_new_construction_task)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _spawn_minion(player: int, castle: Node, position: Vector2, type: String) -> void:
	spawnMinion.emit(player, castle, position, type)


func _new_construction_task(building: Node) -> void:
	newConstructionTask.emit(building)
