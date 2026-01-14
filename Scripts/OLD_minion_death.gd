extends Node
class_name MinionDeath

signal death(agent: Node, me: MinionDeath)

@export var myAgent: CharacterBody2D
@export var health: Health
@export var spawns: String
var myPosition: Vector2


# EDIT THIS FUNCTION TO INSTEAD SPAWN A GOBLIN OR WHATEVER, BY ADDING A SPAWNER TO DEATH.
# I COULD MAYBE EVEN SIMPLIFY THE WHOLE THING BY ADDING A SPAWNER TO HEALTH AND PUT THE CODE THERE.
# THE QUESTION WOULD BE WHAT TO DO WITH RESOURCE COLLECTION... ALA PLANTS... I MIGHT NEED TO RETHINK PLANTS PERHAPS.
# ONE WAY WOULD BE TO SIMPLY KEEP THE TREE, TURN OFF THE COLLISION, AND HAVE IT SPAWN BUSHES ON A TIMER WITH A LOW PERCENTAGE.
# THE PROBLEM THEN IT MIGHT SPAWN WAY TOO MANY IF THERE ARE NO SHEEP... SO IT WOULD ALSO NEED A SPAWNER THAT PRODUCES SHEEP. 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("_connect_health")
	call_deferred("_connect_objects")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _connect_health() -> void:
	if is_instance_valid(health):
		health.healthDepleted.connect(_call_death)


func _connect_objects() -> void:
	var objectsNode = get_tree().get_first_node_in_group("Objects")
	objectsNode.connect_death(self)


func _call_death(attackingPlayer: int) -> void:
	death.emit(myAgent, self)


####
# Called by minion.
####
func return_position() -> Vector2:
	return myAgent.return_position()


func return_spawns() -> String:
	return spawns
