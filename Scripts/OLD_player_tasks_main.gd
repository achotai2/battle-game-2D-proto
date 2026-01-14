extends Node

var deletedTasks: Array[Task] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _task_duplicate(type, sentTask) -> bool:
	for task in get_children():
		if task.tasker == sentTask and task.type == type:
			return true

	return false


func _delete_task(deleteMe: Task) -> void:
	deletedTasks.append(deleteMe)
	
	
func _delete_deleted_tasks() -> void:
	for task in deletedTasks:
		task.queue_free()
	deletedTasks = []


####
# Called by world.
####
func new_task(type: String, sentTask: Node) -> void:
	if !_task_duplicate(type, sentTask):
		var newTask = Task.new()
		newTask.setup_task(type, sentTask)
		newTask.taskCompleted.connect(_delete_task)
		add_child(newTask)


func send_tasks_to_minions(workers: Array) -> void:
	_delete_deleted_tasks()
	
	var assignedWorkers: Array[Node] = []
	
	while get_children().size() > 0 and assignedWorkers.size() < workers.size():
		# Get closest worker to task.
		for task in get_children():
			var closest: int = 0
			var closestWorker: Node = null

			for worker in workers:
				if assignedWorkers.find(worker) == -1 and (closestWorker == null or task.distance_to(worker) < closest):
					closestWorker = worker
					closest = task.distance_to(worker)

			if closestWorker:
				task.assign_task(closestWorker)
				assignedWorkers.append(closestWorker)
