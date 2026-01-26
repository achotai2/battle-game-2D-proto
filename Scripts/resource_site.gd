extends Node2D
class_name ResourceSite

@export var resource_type: ResourceSiteDefs.ResourceType = ResourceSiteDefs.ResourceType.SHEEP
@export var resource_amount: int = 1
@export var spawn_radius: float = 30.0


func spawn() -> void:
	var scene = ResourceSiteDefs.get_scene(resource_type)
	if not scene:
		return
	var instance = scene.instantiate()
	if instance.has_method("set_amount"):
		instance.call("set_amount", resource_amount)
	if instance.has_method("set_castle") and get_parent().has_method("return_castle"):
		var c = get_parent().call("return_castle")
		instance.call("set_castle", c)

	# Add to current scene (World)
	var world = get_tree().current_scene
	if world:
		world.add_child(instance)

		# Position nearby
		var random_angle = randf() * TAU
		var random_dist = randf() * spawn_radius
		var offset = Vector2(cos(random_angle), sin(random_angle)) * random_dist

		instance.global_position = global_position + offset
