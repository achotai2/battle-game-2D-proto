extends Area3D
class_name CastleRegion

@export var owning_castle: Castle


func _ready() -> void:
	collision_layer = 0 
	collision_mask = GamePhysics.get_castle_region_mask()
	
	# Catch any units that physically walk into the zone
	body_entered.connect(_try_assign_castle)
	
	# Create a recurring radar sweep to catch Static objects that pop into existence!
	var sweep_timer = Timer.new()
	sweep_timer.wait_time = 2.0
	sweep_timer.autostart = true
	sweep_timer.timeout.connect(_sweep_territory)
	add_child(sweep_timer)
	
	# Do one immediate sweep just in case
	_sweep_territory()


func _sweep_territory() -> void:
	for body in get_overlapping_bodies():
		_try_assign_castle(body)

	# Fallback: check unassigned buildings manually using the polygon shape.
	# This fixes a Godot 4 broadphase issue with StaticBody3Ds spawned from threads.
	var poly_node = find_child("CollisionPolygon3D", false, false) as CollisionPolygon3D
	if poly_node:
		var poly_2d = poly_node.polygon
		var poly_transform = poly_node.global_transform
		for building in get_tree().get_nodes_in_group("Buildings"):
			if building.has_method("return_castle") and building.return_castle() == null:
				var local_pos = poly_transform.affine_inverse() * building.global_position
				if Geometry2D.is_point_in_polygon(Vector2(local_pos.x, local_pos.y), poly_2d):
					if abs(local_pos.z) <= poly_node.depth / 2.0:
						_try_assign_castle(building)


func _try_assign_castle(body: Node3D) -> void:
	if not is_instance_valid(owning_castle):
		return
		
	if not body is CollisionObject3D:
		return
		
	if not body.has_method("set_castle") or not body.has_method("return_castle"):
		return
		
	var body_layer = body.collision_layer
	
	# --- 1. HANDLE BUILDINGS & TREES ---
	if (body_layer & GamePhysics.get_all_buildings_mask()) != 0:
		if body.return_castle() == null:
			body.set_castle(owning_castle)
		return

	# --- 2. HANDLE UNITS (Strict Team Check) ---
	if (body_layer & GamePhysics.get_all_units_mask()) != 0:
		if body.return_castle() != null:
			return
			
		var unit_team = -1
		
		var team_mem = ComponentFinder.get_component(body, "TeamMemory")
		if team_mem:
			unit_team = team_mem.return_team()
		elif body.get("player") != null:
			unit_team = body.player
			
		if unit_team == owning_castle.player:
			body.set_castle(owning_castle)
