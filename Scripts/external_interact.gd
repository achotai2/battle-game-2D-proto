extends Node
class_name ExternalInteract

signal interactionFinished(interactingPlayer: int)
signal isTarget(interactingPlayer: int)

@export var buildCost: int = 1
@export var spawnCost: int = 1
@export var built: bool = false
@export var timerOffset: Vector2 = Vector2(0, -100)
@export var timerSize: float = 0.1
@export_range(0, 1.0, 0.1) var timerOpacity: float = 0.8
@export var unitSpawnDisplay: Texture
@export var spawnOffset: Vector2 = Vector2(0, 60)
@export var spawnSize: float = 0.5
@export_range(0, 1.0, 0.1) var spawnOpacity: float = 0.8
@export var costOffset: Vector2 = Vector2(50, -100)
@export var costSize: float = 0.5
@export_range(0, 1.0, 0.1) var costOpacity: float = 0.8
#@export var destroyedTooltip: Texture
#@export var builtTooltip: Texture
#@export var tooltipOffset: Vector2 = Vector2(0, -50)
#@export var tooltipSize: Vector2 = Vector2(100, 100)
#@export_range(0, 1.0, 0.1) var tooltipOpacity: float = 0.5

var interactingPlayer: Node
var unitsToSpawn: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$InteractSprite2D.modulate.a = timerOpacity
	$InteractSprite2D.position = get_parent().return_position() + timerOffset

	$EmptySprite2D.modulate.a = timerOpacity
	$EmptySprite2D.scale = Vector2(timerSize, timerSize)
	$EmptySprite2D.position = get_parent().return_position() + timerOffset

	$SpawnDisplay.texture = unitSpawnDisplay
	$SpawnDisplay.modulate.a = spawnOpacity
	$SpawnDisplay.scale = Vector2(spawnSize, spawnSize)
	$SpawnDisplay.position = get_parent().return_position() + spawnOffset

	$SpawnLabel.position = get_parent().return_position() + spawnOffset + Vector2(30, -25)

	$CostDisplay.modulate.a = costOpacity
	$CostDisplay.scale = Vector2(costSize, costSize)
	$CostDisplay.position = get_parent().return_position() + costOffset
	
	$CostLabel.position = get_parent().return_position() + costOffset + Vector2(25, -25)

	_reset_interact_display()

#	$Tooltip.size = tooltipSize
#	$Tooltip.hide()	
#	$Tooltip.modulate.a = tooltipOpacity


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_update_time_step()


func _on_timer_timeout() -> void:
	if _player_has_enough():
		interactionFinished.emit(interactingPlayer.return_my_player())

		var cost := spawnCost if built else buildCost
		interactingPlayer.interaction_finished(cost)

		_reset_interact_display()
		$EmptySprite2D.show()


func _reset_interact_display() -> void:
	$EmptySprite2D.hide()
	$CostDisplay.hide()
	$CostLabel.hide()
	$InteractSprite2D.scale = Vector2(timerSize, timerSize)
	$InteractSprite2D.hide()
	$InteractTimer.stop()


func _update_cost_label() -> void:
	if !built:
		$CostLabel.text = str(buildCost)
		if buildCost > 0:
			$CostDisplay.show()
			$CostLabel.show()
	else:
		$CostLabel.text = str(spawnCost)
		if spawnCost > 0:
			$CostDisplay.show()
			