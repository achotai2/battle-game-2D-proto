extends Node
class_name CastleJobBoard

enum JobBoardType {
	WORKERS,
	PEASANTS,
	FOOD,
}

@export var castle: Castle

# THE FIX: Broaden the array to hold ANY 3D node that acts like a job site!
var _sites: Array[Node3D] = []

# THE FIX: Update the signal payloads so they don't crash when handing off a SpawnSite
signal work_available(site: Node3D)
signal work_completed(site: Node3D)

var _broadcast_timer: Timer

func _ready() -> void:
	if castle == null:
		castle = get_parent() as Castle

	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = 1.0
	_broadcast_timer.autostart = true
	_broadcast_timer.timeout.connect(_on_broadcast_timer_timeout)
	add_child.call_deferred(_broadcast_timer)

# -------------------------
# Work sites
# -------------------------

func register_site(site: Node3D) -> void:
	if site == null or not is_instance_valid(site):
		return
	if _sites.has(site):
		return

	_sites.append(site)
	
	var exit_callable = _on_site_exited.bind(site)
	if not site.tree_exited.is_connected(exit_callable):
		site.tree_exited.connect(exit_callable, CONNECT_ONE_SHOT)

	# New work appeared -> broadcast it
	work_available.emit(site)


func unregister_site(site: Node3D) -> void:
	var idx := _sites.find(site)
	if idx != -1:
		_sites.remove_at(idx)
		
		var exit_callable = _on_site_exited.bind(site)
		if site.tree_exited.is_connected(exit_callable):
			site.tree_exited.disconnect(exit_callable)

	work_completed.emit(site)


func _on_site_exited(site: Node3D) -> void:
	unregister_site(site)

func _on_broadcast_timer_timeout() -> void:
	for site in _sites:
		if is_instance_valid(site):
			if site.has_method("needs_work") and site.needs_work() and site.has_method("has_free_slot") and site.has_free_slot():
				work_available.emit(site)
