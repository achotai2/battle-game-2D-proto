extends Node2D

signal updateGold(gold: int)

@export var goblinScene: PackedScene
@export var soldierScene: PackedScene
@export var archerScene: PackedScene
@export var workerScene: PackedScene
@export var skullScene: PackedScene
@export var arrowScene: PackedScene
@export var goldScene: PackedScene
@export var plantScene: PackedScene
@export var sheepScene: PackedScene
@export var meatScene: PackedScene
@export var woodScene: PackedScene
@export var distanceLookFor: int

var player1: Node
var player2: Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if child.is_in_group("Player"):
			player1 = child
	#		child.projectileLaunched.connect(_agent_ranged_attacking)

		elif child.is_in_group("Minions"):
			_connect_minion(child, child.return_player(), child.return_castle(), child.return_position(), 0)

		elif child == $Trees:
			call_deferred("_add_tree_signals") # Need to call this way since for some reason tilemap children add late.


func _add_tree_signals() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _update_player_gold(gold: int) -> void:
	updateGold.emit(gold)


func _assign_task(tasker: Task, player: int, castle: Node) -> void:
	# Sort by the type of task.
	var assignToMinion: Node
	var minions: Array
	
	if tasker.return_needs_player() == "Any":
		minions = _get_idle_minions(-1, tasker.return_minion_type())
	elif tasker.return_needs_player() == "Mine":
		minions = _get_idle_minions(player, tasker.return_minion_type())
	elif tasker.return_needs_player() == "Neutral":
		minions = _get_idle_minions(0, tasker.return_minion_type())

	assignToMinion = _find_minion_distance(minions, tasker.return_position())
	
	if is_instance_valid(assignToMinion):
		tasker.assign_task(assignToMinion)


func _find_minion_for_castle(minions: Array, castle: Node) -> Node:
	for minion in minions:
		if minion.return_castle() == castle:
			return minion
	return null


func _find_minion_distance(minions: Array, positionToCheck: Vector2) -> Node:
	var closestDistance: float = -1
	var closestMinion: Node 
	
	for minion in minions:
		var distanceMinion: float = positionToCheck.distance_to(minion.return_position())
		if distanceMinion <= distanceLookFor and (closestDistance == -1 or distanceMinion < closestDistance):
			closestDistance = distanceMinion
			closestMinion = minion

	return closestMinion


func _get_idle_minions(player: int, minionType: String) -> Array:
	var minions: Array[Node] = []
	for child in get_children():
		if child.is_in_group(minionType) and is_instance_valid(child.task) and !child.task.has_task():
			if player == -1 or child.return_player() == player:
				minions.append(child)

	return minions


func _agent_ranged_attacking(projectileDictionary: Dictionary) -> void:
	var newProjectile := arrowScene.instantiate()
	add_child(newProjectile)
	newProjectile.setup_projectile(projectileDictionary)
	newProjectile.iWantToDie.connect(_destroy_projectile)


func _destroy_projectile(projectile: Node) -> void:
# PROJECTILE COULD PROBABLY JUST QUEUE FREE ITSELF, NO?
	projectile.queue_free()


func _player_died(agent: Node) -> void:
	pass


func _minion_died(agent: Node, death: MinionDeath) -> void:
	if death.return_spawns() == "Goblin":
		_create_goblin(death.return_position())
	elif death.return_spawns() == "Meat":
		_spawn_resource(agent, "Meat", death.return_position(), 1, 0)

	agent.delete_me()


func _create_goblin(newPosition: Vector2) -> void:
	var newGoblin := goblinScene.instantiate()
	add_child(newGoblin)
	newGoblin.global_position = newPosition
	_connect_minion(newGoblin, 0, null, newPosition, 0)


func _click_spawn_unit(position: Vector2) -> void:
	if randi_range(1, 1) == 0:
		_spawn_unit(randi_range(2, 2), null, 0, position + Vector2(randi_range(-100, 100), randi_range(-100, 100)), "Soldier")
	else:
		_spawn_unit(randi_range(2, 2), null, 0, position + Vector2(randi_range(-100, 100), randi_range(-100, 100)), "Archer")


func _spawn_unit(player: int, castle: Node, goldAmount: int, newPosition: Vector2, type: String) -> void:
	var newMinion: MinionBase

	if type == "Goblin" and goblinScene:
		newMinion = goblinScene.instantiate()
	elif type == "Soldier" and soldierScene:
		newMinion = soldierScene.instantiate()
	elif type == "Archer" and archerScene:
		newMinion = archerScene.instantiate()
	elif type == "Worker" and workerScene:
		newMinion = workerScene.instantiate()
	elif type == "Sheep" and workerScene:
		newMinion = sheepScene.instantiate()

	if newMinion:
		add_child(newMinion)
		_connect_minion(newMinion, player, castle, newPosition, goldAmount)


func _spawn_resource(spawner: Node, type: String, newPosition: Vector2, amount: int, player: int) -> void:
	var newResource: Node
	if type == "Gold" and is_instance_valid(goldScene):
		newResource = goldScene.instantiate()
	elif type == "Meat" and is_instance_valid(meatScene):
		newResource = meatScene.instantiate()
	elif type == "Wood" and is_instance_valid(woodScene):
		newResource = woodScene.instantiate()
	elif type == "Plant" and is_instance_valid(plantScene):
		newResource = plantScene.instantiate()

	add_child(newResource)
	newResource.setup_gold(newPosition, amount, player)
	
	spawner.spawned_this_resource(newResource)


func _connect_minion(minion: Node, player: int, castle: Node, newPosition: Vector2, goldAmount: int) -> void:
	minion.set_position(newPosition)
	minion.set_player(player, castle, goldAmount)


func _castle_destroyed() -> void:
	# Check all castles if they all belong to a single player.
	var numPlayer1Castles: int = 0
	var numPlayer2Castles: int = 0

	for child in get_children():
		if child.is_in_group("Castles"):
			if child.return_player() == 1:
				numPlayer1Castles += 1
			elif child.return_player() == 2:
				numPlayer2Castles += 1

	if numPlayer2Castles == 0:
		$"../CanvasLayer/Player1Wins".show()
	elif numPlayer1Castles == 0:
		$"../CanvasLayer/Player2Wins".show()


#func _replace_it(toReplace: Node, type: String) -> void:
#	var newPosition: Vector2 = toReplace.return_position()
#
#	if toReplace.is_in_group("Trees"):
#		_spawn_wood(newPosition)
#		
#	toReplace.delete_me()
#
#	if type == "Plant":
#		_spawn_plant(newPosition)
#	


####
# Called by world.
####
func get_player_gold_amount() -> int:
	if player1.gold:
		return player1.gold.return_gold()
	else:
		return 0


####
# Called by minions.
####
func get_closest_castle(player: int, newPosition: Vector2) -> Node:
	var castles: Array[Node] = []

	for child in get_children():
		if child.is_in_group("Castles") and child.return_player() == player:
			castles.append(child)

	var closestDistance: float = -1
	var closestCastle: Node 
	for castle in castles:
		var distanceMinion: float = newPosition.distance_to(castle.return_position())
		if closestDistance == -1 or distanceMinion < closestDistance:
			closestDistance = distanceMinion
			closestCastle = castle

	return closestCastle


func connect_death(deathNode: MinionDeath) -> void:
	deathNode.death.connect(_minion_died)


func connect_spawn_click(playerControlNode: PlayerControls) -> void:
	playerControlNode.spawnUnit.connect(_click_spawn_unit)


func connect_projectile(weaponRanged: WeaponRanged) -> void:
	weaponRanged.launchProjectile.connect(_agent_ranged_attacking)


func connect_gold(gold: GoldAgent) -> void:
	gold.updateGold.connect(_update_player_gold)


func connect_task(task: Task) -> void:
	task.needHelp.connect(_assign_task)


func connect_spawns(spawns: Spawns) -> void:
	spawns.spawnUnit.connect(_spawn_unit)
	spawns.spawnResource.connect(_spawn_resource)


func connect_castle(castle: Node) -> void:
	castle.castleDestroyed.connect(_castle_destroyed)
