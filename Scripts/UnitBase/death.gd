extends Node3D
class_name DeathEffect

@export var lifetime: float = 5.0
@export var play_animation: String = "death"
@export var sprite: AnimatedSprite3D = null

func _ready() -> void:
	# 1. Play the bones/death animation if you have one
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(play_animation):
		sprite.play(play_animation)

	# 2. Create a temporary background timer. When it finishes, delete this node.
	await get_tree().create_timer(lifetime).timeout
	queue_free()
