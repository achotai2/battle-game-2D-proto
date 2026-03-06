extends Node
class_name CastleJobBoard

enum JobBoardType {
	WORKERS,
	PEASANTS,
	FOOD,
}

@export var castle: Castle

var _sites: Array[WorkSite] = []

signal work_available(site: WorkSite)
signal work_completed(site: WorkSite)

func _ready() -> void:
	if castle == null:
		castle = get_parent() as Castle

# -------------------------
# Work sites
# -------------------------

func register_site(site: WorkSite) -> void:
	if site == null or not is_instance_valid(site):
		return
	if _sites.has(site):
		return

	_sites.append(site)
	
	# [FIX] Check if already connected before connecting
	# We create the callable variable so we can check the exact bind signature
	var exit_callable = _on_site_exited.bind(site)
	if not site.tree_exited.is_connected(exit_callable):
		site.tree_exited.connect(exit_callable, CONNECT_ONE_SHOT)

	# New work appeared -> broadcast it
	work_available.emit(site)


func unregister_site(site: WorkSite) -> void:
	var idx := _sites.find(site)
	if idx != -1:
		_sites.remove_at(idx)
		
		# [FIX] Clean up the signal connection
		# If we don't do this, re-registering this site later will crash
		var exit_callable = _on_site_exited.bind(site)
		if site.tree_exited.is_connected(exit_callable):
			site.tree_exited.disconnect(exit_callable)

	work_completed.emit(site)


func _on_site_exited(site: WorkSite) -> void:
	# Note: We don't need to manually disconnect here because 
	# CONNECT_ONE_SHOT handles it automatically upon firing.
	unregister_site(site)
