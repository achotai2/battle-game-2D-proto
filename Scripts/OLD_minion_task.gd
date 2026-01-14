extends Node
class_name MinionTask

signal hasTask
signal noTask
signal returnedCarry

@export var taskTime: float = 1
var task: Task
var taskTimer: Timer = Timer.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# Called by tasks when they want to assign this agent to themselves.
func assign_task(newTask: Task) -> void:
	if !has_task():
		task = newTask
		hasTask.emit()


# Called by task when it is completed, to let agent know.
func task_completed() -> void:
	if has_task():
		if task.return_type() == "Return":
			returnedCarry.emit()
		task = null
		noTask.emit()


func task_position() -> Vector2:
	return task.return_position()


func has_task() -> bool:
	if is_instance_valid(task):
		return true
	else:
		return false


func remove_me(myAgent: Node) -> void:
	if has_task():
		task.remove_me(myAgent)
