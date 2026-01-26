extends Node
class_name Hunger

@export var movement: AgentMovement
@export var hunger_amount: int = 1
@export var time_tick: int = 1
@export var min_hunger: int = 0

var _hunger_timer: Timer = Timer.new()
var _huner_move_priority: int = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_child(_hunger_timer)
	_hunger_timer.one_shot = false
	_hunger_timer.wait_time = time_tick
	
	if not _hunger_timer.timeout.is_connected(_on_hunger_timer_timeout):
		_hunger_timer.timeout.connect(_on_hunger_timer_timeout)

	var stagger_time = randf_range(0.0, 1.0)
	_hunger_timer.start(stagger_time)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_movement(m: AgentMovement) -> void:
	movement = m


#Swap food over to job board handled by the castle.
#	Every minion at the castle registers with the food job board.
#	When they are hungry it assigns them a food, has them run over to it and apply work and get the food.
#Really they apply work to a sheep, or to a building storing food. The sheep or building then hands the food resource over.
#Resources will be handled like that, in that they aren't floating in the world, they are always in someones hand.
#	Therefore it makes sense to have them spawn and run animation inside the GoldHolder and Hunger nodes themselves.
#	Then, when GoldHolder and Hunger do the handoff those nodes themselves will handle the animations.
#	If I want to add floating resources later, on the ground, then I can add it as a different structure. 
func _on_hunger_timer_timeout() -> void:
	hunger_amount -= 1
	
	if hunger_amount <= min_hunger:
		var castle: Node = get_parent().return_castle()
		var position: Vector2 = get_parent().return_position()
		var nearest: Node2D = castle.get_nearest(&"sheep", position)

		if is_instance_valid(movement) and is_instance_valid(nearest):
			movement.command_chase_target(nearest, _huner_move_priority)
