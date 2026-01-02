extends Node
class_name Spawns

# Signal is sent to Objects in world, to spawn new unit.
signal spawnUnit(player: int, castle: Node, gold: int, newPosition: Vector2, type: String)
signal spawnResource(spawner: Node, type: String, newPosition: Vector2, amount: int, player: int)

@export var myAgent: Node
@export_enum("Goblin", "Soldier", "Worker", "Archer", "Sheep", "Gold", "Wood", "Meat", "Plant") var spawns: String = "Soldier"
var resources: Array[String] = ["Gold", "Wood", "Meat", "Plant"]
@export_range(0, 10, 0.1) var timeToSpawn: float = 1
@export_range(0, 1, 0.000001) var probabilityToSpawn: float = 1.0
@export var timerToSpawn: bool = false
var spawnTimer: Timer = Timer.new()



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawnTimer.wait_time = timeToSpawn
	spawnTimer.one_shot = false
	spawnTimer.timeout.connect(_on_timer_timeout)
	add_child(spawnTimer)

	call_deferred("_connect_objects")

	if timerToSpawn:
		spawnTimer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	randomize()
	var randomFloat: float = randf_range(0.0, 1.0)
	if randomFloat <= probabilityToSpawn:
		spawn_unit()


func _connect_objects() -> void:
	var objectsNode = get_tree().get_first_node_in_group("Objects")
	objectsNode.connect_spawns(self)


####
# Called by the agent.
####
func spawn_unit() -> void:
	spawn_unit_at(myAgent.return_position(), 0)


func spawn_resource(amount: int) -> void:
	spawnResource.emit(myAgent, spawns, myAgent.return_position(), amount,  myAgent.return_player())


func spawn_unit_at(position: Vector2, goldAmount: int) -> void:
	if spawns in resources:
		spawnResource.emit(myAgent, spawns, position, myAgent.return_amount(),  myAgent.return_player())
	else:
		spawnUnit.emit(myAgent.return_player(), myAgent.return_castle(), goldAmount, position, spawns)


func return_spawn_type() -> String:
	return spawns


func change_timer_to_spawn(newState: bool) -> void:
	timerToSpawn = newState
	if timerToSpawn:
		spawnTimer.start()
