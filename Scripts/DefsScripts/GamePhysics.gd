class_name GamePhysics

const LAYER_TILESET = 1
const LAYER_BUILDINGS = 2
const LAYER_ATTACKABLE_NEUTRAL = 3
const LAYER_ATTACKABLE_PLAYER_1 = 4
const LAYER_ATTACKABLE_PLAYER_2 = 5
const LAYER_INTERACTABLE_NEUTRAL = 6
const LAYER_INTERACTABLE_PLAYER_1 = 7
const LAYER_INTERACTABLE_PLAYER_2 = 8
const LAYER_TRACKING = 9
const LAYER_WORKSITE = 10
const LAYER_PROJECTILE = 11
const LAYER_PEASANTS = 12

static func get_mask_bit(layer: int) -> int:
	return 1 << (layer - 1)


static func get_minion_layer(player_id: int, is_peasant: bool = false) -> int:
	if is_peasant:
		return get_mask_bit(LAYER_PEASANTS)
	match player_id:
		0: return get_mask_bit(LAYER_ATTACKABLE_NEUTRAL)
		1: return get_mask_bit(LAYER_ATTACKABLE_PLAYER_1)
		2: return get_mask_bit(LAYER_ATTACKABLE_PLAYER_2)
	return 0


static func get_minion_movement_mask() -> int:
	# Only collide with the World (TileMap) and Buildings
	return get_mask_bit(LAYER_TILESET) | get_mask_bit(LAYER_BUILDINGS)
	

static func get_building_layer() -> int:
	return get_mask_bit(LAYER_BUILDINGS)


static func get_tracking_mask(my_player_id: int, target_neutral: bool, target_opposing: bool, target_own: bool) -> int:
	var mask = 0

	var p0 = get_mask_bit(LAYER_ATTACKABLE_NEUTRAL)
	var p1 = get_mask_bit(LAYER_ATTACKABLE_PLAYER_1)
	var p2 = get_mask_bit(LAYER_ATTACKABLE_PLAYER_2)

	# Target Own
	if target_own:
		match my_player_id:
			0: mask |= p0
			1: mask |= p1
			2: mask |= p2

	# Target Neutral (Faction 0)
	if target_neutral:
		# Only target neutral if I am NOT neutral, or if I explicitly want to target own (neutral)
		if my_player_id != 0 or target_own:
			mask |= p0

	# Target Opposing
	if target_opposing:
		match my_player_id:
			0: mask |= p1 | p2
			1: mask |= p2
			2: mask |= p1

	return mask


static func get_projectile_mask() -> int:
	return get_mask_bit(LAYER_ATTACKABLE_NEUTRAL) | \
		   get_mask_bit(LAYER_ATTACKABLE_PLAYER_1) | \
		   get_mask_bit(LAYER_ATTACKABLE_PLAYER_2) | \
		   get_mask_bit(LAYER_BUILDINGS)


static func get_global_mouse_position_3d(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, 0)
	var intersection = plane.intersects_ray(from, dir)
	if intersection != null:
		return intersection
	return Vector3.ZERO
