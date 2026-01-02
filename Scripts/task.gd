extends Node
class_name Task

signal needHelp(me: Task, player: int, castle: Node)
signal taskFinished

var assignedTo: Array[Node] = []
var position: Vector2
var needTimer = Timer.new()
@export var myAgent: Node
@export var taskNeeds: String
@export var taskType: String
@export_enum("Mine", "Enemy", "Neutral", "Any") var needsPlayer: String = "Mine"
@export var spawns: Spawns
@export var detection: Area2D
@export var needTimerTime: float = 1.0
@export var startsOn: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	needTimer.wait_time = needTimerTime
	needTimer.one_shot = false
	add_child(needTimer)
	needTimer.timeout.connect(_need_help)
	
	call_deferred("_connect_objects")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _need_help() -> void:
	needHelp.emit(self, myAgent.return_player(), myAgent.return_castle())

