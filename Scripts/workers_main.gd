extends Node

signal minionDied(agent: Node)

@export var soldierScene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		child.i_died.connect(_minion_died)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _minion_died(agent: Node) -> void:
	minionDied.emit(agent)
	
	
####
# Called by world.
####
func spawn_unit(position: Vector2) -> void:
	if soldierScene:
		var newSoldier = soldierScene.instantiate()

		newSoldier.set_player(randi_range(1, 2))
		add_child(newSoldier)
		newSoldier.set_position(position)
		
		newSoldier.i_died.connect(_minion_died)
