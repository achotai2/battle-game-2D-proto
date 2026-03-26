extends Area3D
class_name CastleRegion

@export var owning_castle: Castle

var sweep_timer: Timer

func _ready() -> void:
	# 1. Setup Physics
	collision_layer = 0 
	collision_mask = GamePhysics.get_castle_region_mask()
	
	# 2. Connect physical entry
	if not body_entered.is_connected(_try_assign_castle):
		body_entered.connect(_try_assign_castle)
	
	# 3. Setup and start the radar sweep
	sweep_timer = Timer.new()
	sweep_timer.wait_time = 2.0
	sweep_timer.autostart = true # Now it starts on its own!
	sweep_timer.timeout.connect(_sweep_territory)
	add_child(sweep_timer)
	
	# 4. Do one immediate sweep on boot
	# We defer this to the end of the frame to ensure all other nodes (like Proton Scatter trees) 
	# have finished their own _ready() functions and are in the "Buildings" group.
	call_deferred("_sweep_territory")


func _sweep_territory() -> void:
	for body in get_overlapping_bodies():
		_try_assign_castle(body)

	# Fallback: check unassigned buildings manually using the polygon shape.
	var poly_node = find_child("CollisionPolygon3D", false, false) as CollisionPolygon3D
	if poly_node:
		var poly_2d = poly_node.polygon
		var inverse_transform = poly_node.global_transform.affine_inverse()
		var half_depth = poly_node.depth / 2.0

		var buildings = get_tree().get_nodes_in_group("Buildings")
		
		# Loops over "Buildings" (which includes Trees, thanks to BuildingBase._ready!)
		for building in buildings:
			if building.has_method("return_castle") and building.return_castle() == null:
				var local_pos = inverse_transform * building.global_position
				if abs(local_pos.z) <= half_depth:
					if Geometry2D.is_point_in_polygon(Vector2(local_pos.x, local_pos.y), poly_2d):
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
		
		var team_mem = body.get("team") if body.get("team") else body.get("team_memory")
		if team_mem:
			unit_team = team_mem.return_team()
		elif body.get("player") != null:
			unit_team = body.player
			
		if unit_team == owning_castle.player:
			body.set_castle(owning_castle)
