extends Node

signal projectileLaunched(projectileDictionary: Dictionary)
signal minionDied(agent: Node)

@export var soldierScene: PackedScene
@export var archerScene: PackedScene
@export var workerScene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		child.projectileLaunched.connect(_agent_ranged_attacking)
		child.i_died.connect(_minion_died)
		child.set_player(child.return_player(), child.return_castle())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _agent_ranged_attacking(projectileDictionary: Dictionary) -> void:
	projectileLaunched.emit(projectileDictionary)


func _minion_died(agent: Node) -> void:
	minionDied.emit(agent)


####
# Called by world.
####
func spawn_unit(player: int, castle: Node, position: Vector2, type: String) -> void:
	var newMinion: MinionBase

	if type == "Soldier" and soldierScene:
		newMinion = soldierScene.instantiate()
	elif type == "Archer" and archerScene:
		newMinion = archerScene.instantiate()
	elif type == "Worker" and workerScene:
		newMinion = workerScene.instantiate()

	add_child(newMinion)
	newMinion.set_player(player, castle)
	newMinion.set_position(position)
	newMinion.projectileLaunched.connect(_agent_ranged_attacking)

	newMinion.i_died.connect(_minion_died)


func get_workers(player: int) -> Array:
	var workers: Array[Node] = []
	
	for child in get_children():
		if child.is_in_group("Workers") and child.return_player() == player:
			workers.append(child)

	return workers
