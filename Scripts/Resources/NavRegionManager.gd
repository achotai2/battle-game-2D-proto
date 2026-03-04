extends NavigationRegion3D
class_name NavRegionManager


func _ready() -> void:
	# We use call_deferred to wait for the very end of the first frame.
	# This guarantees HTerrain has finished building its physics collision!
	call_deferred("rebake_map")


func rebake_map() -> void:
	print("Baking RTS NavMesh...")
	
	# Godot 4's built-in runtime baker.
	# Passing 'true' tells it to bake on a background thread so the game doesn't freeze!
	bake_navigation_mesh(true)


func _init() -> void:
	# Connect the built-in completion signal to our own print function
	bake_finished.connect(_on_bake_finished)


func _on_bake_finished() -> void:
	print("NavMesh Bake Complete.")
