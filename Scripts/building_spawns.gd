extends Node
class_name Spawns

signal spawnUnit(spawnType: String, translation: Vector2)

@export_enum("Soldier", "Worker", "Archer") var spawns: String = "Soldier"
@export_range(0, 10, 0.1) var timeToSpawn: float = 1
@export_range(0, 1, 0.000001) var probabilityToSpawn: float = 1.0
@export var timerToSpawn: bool = false
@export var spawnTranslation: Vector2 = Vector2(0, 30)
var spawnTimer: Timer = Timer.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawnTimer.wait_time = timeToSpawn
	spawnTimer.one_shot = false
	spawnTimer.timeout.connect(_on_timer_timeout)
	add_child(spawnTimer)

	if timerToSpawn:
		spawnTimer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	_spawn_emit()


func _spawn_emit() -> void:
	randomize()
	var randomFloat: float = randf_range(0.0, 1.0)
	if randomFloat <= probabilityToSpawn:
		spawnUnit.emit(spawns, spawnTranslation)


####
# Called by the agent.
####
func spawn_unit() -> void:
	if !timerToSpawn:
		_spawn_emit()
