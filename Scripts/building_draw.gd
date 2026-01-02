extends Node
class_name BuildingDraw

@export var sprite: Sprite2D
@export var destroyedTexture: Texture
@export var player1Texture: Texture
@export var player2Texture: Texture
@export var buildingTexture: Texture
@export_range(0, 3, 0.1) var damageVisualTime: float = 0.2
@export_range(0, 3, 0.1) var buildVisualTime: float = 0.2

var damageTimer := Timer.new()
var buildTimer := Timer.new()

var startPosition: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# The damage flash timer.
	damageTimer.wait_time = damageVisualTime
	damageTimer.one_shot = true
	damageTimer.timeout.connect(_damage_on_timer_timeout)
	add_child(damageTimer)

	# The build flash timer.
	buildTimer.wait_time = buildVisualTime
	buildTimer.one_shot = true
	buildTimer.timeout.connect(_build_on_timer_timeout)
	add_child(buildTimer)

	if sprite:
		startPosition = sprite.position

	elif animatedSprite:
		startPosition = animatedSprite.position
		animatedSprite.play("destroyed")
		randomize()
		animatedSprite.frame = randi_range(0, animatedSprite.sprite_frames.get_frame_count("destroyed") - 1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !damageTimer.is_stopped():
		_update_damage_visual()

	if !buildTimer.is_stopped():
		_update_build_visual()


func _damage_on_timer_timeout() -> void:
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("progress", 0)


func _build_on_timer_timeout() -> void:
	if sprite:
		sprite.position = startPosition


func _update_damage_visual() -> void:
	if sprite and sprite.material:
		var percent: float = float(damageTimer.wait_time - damageTimer.time_left) / damageTimer.wait_time
		sprite.material.set_shader_parameter("progress", percent)


func _update_build_visual() -> void:
	if sprite:
		var vibrate: Vector2 = startPosition + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		sprite.position = vibrate


####
# Called by building.
####
func update_draw_state(player: int, destroyed: bool, construction: bool) -> void:
	if sprite:
		if destroyed:
			if destroyedTexture: sprite.texture = destroyedTexture
		elif construction:
			if buildingTexture: sprite.texture = buildingTexture
		else:
			if player == 1 and player1Texture: sprite.texture = player1Texture
			if player == 2 and player2Texture: sprite.texture = player2Texture

	elif animatedSprite:
		if destroyed:
			animatedSprite.play("destroyed")
		elif construction:
			animatedSprite.play("building")
		else:
			if player == 0:
				animatedSprite.play("built0")
			elif player == 1:
				animatedSprite.play("built1")
			elif player == 2:
				animatedSprite.play("built2")


func received_damage() -> vo
