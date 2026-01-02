extends Node2D
class_name PlayerControls

signal buildEngaged
signal buildReleased
signal moveAgent(direction: Vector2)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("_connect_objects")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Get player input.
	if Input.is_action_just_pressed("build"):
		buildEngaged.emit()
	elif Input.is_action_just_released("build"):
		buildReleased.emit()

	# Get the input direction and handle the movement/deceleration.
	var directionX := Input.get_axis("move_left", "move_right")
	var directionY := Input.get_axis("move_up", "move_down")
	moveAgent.emit(Vector2(directionX, directionY))


func _connect_objects() -> void:
	var objectsNode = get_tree().get_first_node_in_group("Objects")
	if is_instance_valid(objectsNode):
		objectsNode.connect_spawn_click(self)
