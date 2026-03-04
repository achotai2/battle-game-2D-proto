extends Node
class_name CastleJobBoard

enum JobBoardType {
	WORKERS,
	PEASANTS,
	FOOD,
}

@export var castle: Castle

var _sites: Array[WorkSite] = []
var _reserved_by: Dictionary = {} # site: Array[AgentBase] (agents)
var _idle_minions: Array[MinionTasker] = []

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
	_assign_if_possible()


func unregister_site(site: WorkSite) -> void:
	_release_site(site)
	var idx := _sites.find(site)
	if idx != -1:
		_sites.remove_at(idx)
		
		# [FIX] Clean up the signal connection
		# If we don't do this, re-registering this site later will crash
		var exit_callable = _on_site_exited.bind(site)
		if site.tree_exited.is_connected(exit_callable):
			site.tree_exited.disconnect(exit_callable)

	work_completed.emit(site)
	_assign_if_possible()


func _on_site_exited(site: WorkSite) -> void:
	# Note: We don't need to manually disconnect here because 
	# CONNECT_ONE_SHOT handles it automatically upon firing.
	unregister_site(site)

# -------------------------
# Minions
# -------------------------

func register_minion(minion: MinionTasker) -> void:
	if minion == null or not is_instance_valid(minion):
		return

	# [FIX] Same safety check for minions
	var exit_callable = _on_minion_exited.bind(minion)
	if not minion.tree_exited.is_connected(exit_callable):
		minion.tree_exited.connect(exit_callable, CONNECT_ONE_SHOT)

func unregister_minion(minion: MinionTasker) -> void:
	# Remove from idle list if present
	var idx := _idle_minions.find(minion)
	if idx != -1:
		_idle_minions.remove_at(idx)
	
	# [FIX] Clean up signal so minion can be re-registered safely
	var exit_callable = _on_minion_exited.bind(minion)
	if minion.tree_exited.is_connected(exit_callable):
		minion.tree_exited.disconnect(exit_callable)

	# Release any reservations held by this minion
	var agent := _resolve_agent(minion)
	if agent != null:
		_release_reservations_for_agent(agent)

	_assign_if_possible()


func _on_minion_exited(minion: Node) -> void:
	unregister_minion(minion)


func minion_idle(minion: MinionTasker) -> void:
	if minion == null or not is_instance_valid(minion):
		return
	if not _idle_minions.has(minion):
		_idle_minions.append(minion)
	_assign_if_possible()


func register_worker(minion: MinionTasker) -> void:
	register_minion(minion)


func unregister_worker(minion: MinionTasker) -> void:
	unregister_minion(minion)


# minion calls this when abandoning/completing a job
func release_job(site: WorkSite, minion: MinionTasker) -> void:
	if site == null:
		return
	var agent := _resolve_agent(minion)
	if agent != null:
		_release_reservation(site, agent)
		_assign_if_possible()


func request_job(minion: MinionTasker) -> WorkSite:
	if minion == null or not is_instance_valid(minion):
		return null

	_prune_invalid_sites()
	_prune_invalid_minions()

	var agent := _resolve_agent(minion)
	if agent == null:
		return null

	var attempted: Array[WorkSite] = []
	var site := _pick_best_site_for_minion(minion, agent, attempted)
	while site != null:
		if _reserve(site, agent):
			return site
		attempted.append(site)
		site = _pick_best_site_for_minion(minion, agent, attempted)
	return null


# -------------------------
# Assignment
# -------------------------

func _assign_if_possible() -> void:
	_prune_invalid_sites()
	_prune_invalid_minions()

	# Iterate idle minions and give each one a job if possible
	for i in range(_idle_minions.size() - 1, -1, -1):
		var w := _idle_minions[i]
		var agent := _resolve_agent(w)
		if agent == null:
			continue

		var attempted: Array[WorkSite] = []
		var site := _pick_best_site_for_minion(w, agent, attempted)
		while site != null:
			if _reserve(site, agent):
				_idle_minions.remove_at(i)
				w.assign_job(site)
				break
			attempted.append(site)
			site = _pick_best_site_for_minion(w, agent, attempted)


func _pick_best_site_for_minion(minion: MinionTasker, agent: AgentBase, excluded_sites: Array[WorkSite] = []) -> WorkSite:
	var best: WorkSite = null
	var best_score: float = INF
	
	# Cache minion position once
	var minion_pos = minion.return_position()

	for site in _sites:
		if excluded_sites.has(site):
			continue
		if not _site_needs_work(site):
			continue

		# Optional site-side reservation rule
		if site.has_method("can_reserve"):
			if not site.can_reserve(agent):
				continue
		
		var wp := _get_site_pos(site, agent)
		var d2 : float = minion_pos.distance_squared_to(wp)
		if d2 < best_score:
			best_score = d2
			best = site

	return best


# -------------------------
# Internals
# -------------------------

func _reserve(site: WorkSite, agent: AgentBase) -> bool:
	if not is_instance_valid(site):
		return false
	if site.has_method("reserve"):
		if not site.reserve(agent):
			return false

	var reserved = _reserved_by.get(site, [])
	if not reserved.has(agent):
		reserved.append(agent)
	_reserved_by[site] = reserved
	return true


func _release_site(site: WorkSite) -> void:
	if _reserved_by.has(site):
		var agents: Array = _reserved_by[site]
		_reserved_by.erase(site)
		if is_instance_valid(site) and site.has_method("unreserve"):
			for agent in agents:
				if is_instance_valid(agent):
					# Check validity again for safety
					if is_instance_valid(site):
						site.unreserve(agent)
					
					if is_instance_valid(agent.tasker) and agent.tasker.has_method("clear_task"):
						agent.tasker.clear_task()
			
		else:
			# If site is gone, we can't unreserve on it, but we should clear agent tasks
			for agent in agents:
				if is_instance_valid(agent) and is_instance_valid(agent.tasker) and agent.tasker.has_method("clear_task"):
					agent.tasker.clear_task()


func _release_reservation(site: WorkSite, agent: AgentBase) -> void:
	if not _reserved_by.has(site):
		return
	var agents: Array = _reserved_by[site]
	var idx := agents.find(agent)

	if idx != -1:
		agents.remove_at(idx)
		if is_instance_valid(site) and site.has_method("unreserve"):
			site.unreserve(agent)

	if agents.is_empty():
		_reserved_by.erase(site)
	else:
		_reserved_by[site] = agents


func _release_reservations_for_agent(agent: AgentBase) -> void:
	# Duplicate keys to avoid modification during iteration issues
	var sites = _reserved_by.keys()
	for site in sites:
		_release_reservation(site, agent)


func _prune_invalid_sites() -> void:
	for i in range(_sites.size() - 1, -1, -1):
		var s := _sites[i]
		if s == null or not is_instance_valid(s):
			_sites.remove_at(i)
			_reserved_by.erase(s)


func _prune_invalid_minions() -> void:
	for i in range(_idle_minions.size() - 1, -1, -1):
		if _idle_minions[i] == null or not is_instance_valid(_idle_minions[i]):
			_idle_minions.remove_at(i)


func _site_needs_work(site: WorkSite) -> bool:
	return site.needs_work()


func _get_site_pos(site: WorkSite, agent: AgentBase) -> Vector3:
	if site.has_method("get_work_position_for"):
		return site.get_work_position_for(agent)
	return site.get_work_position()


func _resolve_agent(minion: MinionTasker) -> AgentBase:
	if minion == null:
		return null
	return minion.get_agent()
