extends Node
class_name CastleJobBoard

enum JobBoardType {
	WORKERS,
	PEASANTS,
	FOOD,
}

@export var castle: Node2D
## Deprecated: slot-based capacity now comes from WorkSite.can_reserve/reserve.
## This flag is kept for compatibility but no longer used.

var _sites: Array[WorkSite] = []
var _reserved_by: Dictionary = {} # site: Array[Node2D] (agents)

var _idle_minions: Array[WorkSiteWorker] = []


func _ready() -> void:
	if castle == null:
		castle = get_parent() as Node2D


# -------------------------
# Work sites
# -------------------------

func register_site(site: WorkSite) -> void:
	if site == null or not is_instance_valid(site):
		return
	if _sites.has(site):
		return

	_sites.append(site)
	site.tree_exited.connect(_on_site_exited.bind(site), CONNECT_ONE_SHOT)

	# New work appeared -> try assign immediately
	_assign_if_possible()


func unregister_site(site: WorkSite) -> void:
	_release_site(site)
	var idx := _sites.find(site)
	if idx != -1:
		_sites.remove_at(idx)

	_assign_if_possible()


func _on_site_exited(site: WorkSite) -> void:
	unregister_site(site)


# -------------------------
# minions
# -------------------------

func register_minion(minion: WorkSiteWorker) -> void:
	if minion == null or not is_instance_valid(minion):
		return

	# Clean up if minion is freed
	minion.tree_exited.connect(_on_minion_exited.bind(minion), CONNECT_ONE_SHOT)


func unregister_minion(minion: WorkSiteWorker) -> void:
	# Remove from idle list if present
	var idx := _idle_minions.find(minion)
	if idx != -1:
		_idle_minions.remove_at(idx)

	# Release any reservations held by this minion
	var agent := _resolve_agent(minion)
	if agent != null:
		_release_reservations_for_agent(agent)

	_assign_if_possible()


func _on_minion_exited(minion: Node) -> void:
	unregister_minion(minion)


func minion_idle(minion: WorkSiteWorker) -> void:
	if minion == null or not is_instance_valid(minion):
		return
	if not _idle_minions.has(minion):
		_idle_minions.append(minion)
	_assign_if_possible()


func register_worker(minion: WorkSiteWorker) -> void:
	register_minion(minion)


func unregister_worker(minion: WorkSiteWorker) -> void:
	unregister_minion(minion)


# minion calls this when abandoning/completing a job
func release_job(site: WorkSite, minion: WorkSiteWorker) -> void:
	if site == null:
		return
	var agent := _resolve_agent(minion)
	if agent != null:
		_release_reservation(site, agent)
		_assign_if_possible()


func request_job(minion: WorkSiteWorker) -> WorkSite:
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


func _pick_best_site_for_minion(minion: WorkSiteWorker, agent: Node2D, excluded_sites: Array[WorkSite] = []) -> WorkSite:
	var best: WorkSite = null
	var best_score: float = INF

	for site in _sites:
		if excluded_sites.has(site):
			continue
		if not _site_needs_work(site):
			continue

		# Optional site-side reservation rule
		if site.has_method("can_reserve"):
			if not bool(site.call("can_reserve", agent)):
				continue
		else:
			print_debug("site does not have function can_reserve")

		var wp := _get_site_pos(site, agent)
		var d2 : float = minion.return_position().distance_squared_to(wp)
		if d2 < best_score:
			best_score = d2
			best = site

	return best


# -------------------------
# Internals
# -------------------------

func _reserve(site: WorkSite, agent: Node2D) -> bool:
	if not is_instance_valid(site):
		return false
	if site.has_method("reserve"):
		if not bool(site.call("reserve", agent)):
			return false
	else:
		print_debug("site does not have function reserve")

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
					if is_instance_valid(site) and site.has_method("unreserve"):
						site.call("unreserve", agent)
					else:
						print_debug("site doesn't exist or doesnt have function unreserve.")
					if is_instance_valid(agent.tasker) and agent.tasker.has_method("clear_task"):
						agent.tasker.call("clear_task")
					else:
						print_debug("agent doesn't exist or doesnt have function clear_task.")
			
		else:
			print_debug("site does not exist or does not have function unreserve")


func _release_reservation(site: WorkSite, agent: Node2D) -> void:
	if not _reserved_by.has(site):
		return
	var agents: Array = _reserved_by[site]
	var idx := agents.find(agent)

	if idx != -1:
		agents.remove_at(idx)
		if is_instance_valid(site) and site.has_method("unreserve"):
			site.call("unreserve", agent)
		else:
			print_debug("site does not exist or does not have function unreserve")

	if agents.is_empty():
		_reserved_by.erase(site)
	else:
		_reserved_by[site] = agents


func _release_reservations_for_agent(agent: Node2D) -> void:
	for site in _reserved_by.keys():
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


func _get_site_pos(site: WorkSite, agent: Node2D) -> Vector2:
	if site.has_method("get_work_position_for"):
		return site.call("get_work_position_for", agent)
	else:
		print_debug("site does not have function get_work_position_for")
	return site.get_work_position()


func _resolve_agent(minion: WorkSiteWorker) -> Node2D:
	if minion == null:
		return null

	return minion.get_agent()
