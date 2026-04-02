extends StaticBody3D
class_name Castle

@export var player: int = 0
@export var peasant_job_board: CastleJobBoard
@export var worker_job_board: CastleJobBoard
@export var food_job_board: CastleJobBoard
@export var territory_grid: GridMap

# --- Spawner Settings ---
@export_category("Territory Spawner")
@export var tree_scene: PackedScene
@export var trees_per_cell: int = 3
@export var y_offset: float = -1.0
@export var small_scale: float = 0.8
@export var large_scale: float = 1.2

var minions: Dictionary = {}


func _ready() -> void:
	# 1. Generate the trees from the painted grid
	_generate_and_claim_trees()
	
	# 2. Hide the ugly blue grid
	if territory_grid:
		territory_grid.hide()


func return_job_board(kind: CastleJobBoard.JobBoardType) -> CastleJobBoard:
	if kind == CastleJobBoard.JobBoardType.WORKERS:
		return worker_job_board
	elif kind == CastleJobBoard.JobBoardType.PEASANTS:
		return peasant_job_board
	elif kind ==  CastleJobBoard.JobBoardType.FOOD:
		return food_job_board
	else:
		return null


func register_minion(minion: AgentBase) -> void:
	if not minions.has(minion):
		minions[minion] = true


func unregister_minion(minion: AgentBase) -> void:
	minions.erase(minion)


func get_active_minions() -> Array:
	return minions.keys()


# ==========================================
# TERRITORY & RESOURCE MANAGEMENT
# ==========================================

func _generate_and_claim_trees() -> void:
	if not territory_grid or not tree_scene:
		print(name, " is missing its GridMap or Tree Scene!")
		return

	var painted_cells = territory_grid.get_used_cells()
	var cell_size = territory_grid.cell_size
	var jobs_posted = 0

	for cell in painted_cells:
		var local_cell_center = territory_grid.map_to_local(cell)
		var global_cell_center = territory_grid.to_global(local_cell_center)

		for i in range(trees_per_cell):
			var tree = tree_scene.instantiate()
			
			# Add it as a direct child of the Castle
			add_child(tree) 
			
			# Scatter math
			var offset_x = randf_range(-cell_size.x / 2.0, cell_size.x / 2.0)
			var offset_z = randf_range(-cell_size.z / 2.0, cell_size.z / 2.0)
			
			tree.global_position = global_cell_center + Vector3(offset_x, y_offset, offset_z)
			
			# Rotation and Scale
			tree.rotation.y = randf_range(0, TAU)
			var random_scale = randf_range(small_scale, large_scale)
			tree.scale = Vector3(random_scale, random_scale, random_scale)
			
			# --- CLAIM IT & POST JOB ---
			if "building_type" in tree and tree.building_type == BuildingDefs.BuildingType.TREE:
				if tree.has_method("set_castle"):
					tree.set_castle(self)
					
				if peasant_job_board:
					# peasant_job_board.post_job("chop_wood", tree)
					jobs_posted += 1
					
	print(name, " generated and posted jobs for ", jobs_posted, " trees at runtime!")
