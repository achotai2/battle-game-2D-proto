extends Node

## Helper script to update terrain shader parameters for the "Vision Tube" cutout effect.
## Attach this to a node in your scene and assign the Terrain, Player, and Camera.

@export var terrain: Node3D ## The HTerrain node
@export var player: Node3D ## The Player node
@export var camera: Camera3D ## The Camera node (optional, falls back to viewport camera)

@export var cutout_radius: float = 2.0
@export var cutout_softness: float = 1.0

@export_range(0.0, 180.0) var cutout_slope_min: float = 0.0
@export_range(0.0, 180.0) var cutout_slope_max: float = 180.0

func _process(delta: float):
	if not is_instance_valid(terrain):
		return

	if not terrain.has_method("set_shader_param"):
		return

	var cam := camera
	if not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d()

	if not is_instance_valid(cam):
		return

	var p_pos := Vector3.ZERO
	if is_instance_valid(player):
		p_pos = player.global_position

	terrain.set_shader_param("u_cutout_player_position", p_pos)
	terrain.set_shader_param("u_cutout_camera_position", cam.global_position)
	terrain.set_shader_param("u_cutout_radius", cutout_radius)
	terrain.set_shader_param("u_cutout_softness", cutout_softness)

	var slope_min_cos = cos(deg_to_rad(cutout_slope_max))
	var slope_max_cos = cos(deg_to_rad(cutout_slope_min))
	terrain.set_shader_param("u_cutout_slope_cos_range", Vector2(slope_min_cos, slope_max_cos))
