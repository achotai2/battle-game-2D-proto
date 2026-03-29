extends Node3D
class_name EnvironmentRadar

signal state_changed(is_over_threshold: bool)
signal scan_completed(count: int)

@export var scan_radius: float = 5.0
@export var threshold: int = 4

@export var auto_scan: bool = false
@export var scan_interval: float = 5.0

var is_over_threshold: bool = false
var current_count: int = 0
var _timer: Timer = null
var _my_boss: Node = null


func _ready() -> void:
	_my_boss = ComponentFinder.get_base(self)
	
	if auto_scan:
		_timer = Timer.new()
		_timer.wait_time = scan_interval
		_timer.autostart = true
		# We don't care about the return value for the timer, so ignoring it is fine
		_timer.timeout.connect(_auto_scan_trigger) 
		_timer.start(scan_interval + randf_range(0.0, 0.5)) 
		add_child(_timer)


func force_scan() -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = scan_radius
	query.shape = sphere
	query.transform = self.global_transform
	
	query.collision_mask = GamePhysics.get_mask_bit(GamePhysics.LAYER_TREES) 
	
	var space_state = get_world_3d().direct_space_state
	var results = space_state.intersect_shape(query, 64) 
	
	var count = 0
	
	for res in results:
		var body = res["collider"]
		if body != _my_boss and is_instance_valid(body):
			count += 1
			
	current_count = count
	scan_completed.emit(count)
	
	# Update the state and fire the signal just in case UI wants to listen
	var new_state = (count >= threshold)
	if new_state != is_over_threshold:
		is_over_threshold = new_state
		state_changed.emit(is_over_threshold)
		
	# RETURN THE BOOL!
	return is_over_threshold


func _auto_scan_trigger() -> void:
	if _my_boss and _my_boss.building_type == BuildingDefs.BuildingType.VILLAGE and not force_scan() and _my_boss.buildingDeath:
		_my_boss.buildingDeath.trigger_death()
		
