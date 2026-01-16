extends Node
class_name CastleJobBoard

@export var castle: Node2D
@export var one_minion_per_site: bool = true

var _sites: Array[WorkSite] = []
var _reserved_by: Dictionary = {} # site: minion

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
	for site in _reserved_by.keys():
		if _reserved_by.get(site) == minion:
			_release_site(site)

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
	if _reserved_by.get(site) == minion:
		_release_site(site)
	_assign_if_possible()


func request_job(minion: WorkSiteWorker) -> WorkSite:
	if minion == null or not is_instance_valid(minion):
		return null

	_prune_invalid_sites()
	_prune_invalid_minions()

	var site := _pick_best_site_for_minion(minion)
	if site == null:
		return null

	_reserve(site, minion)
	return site


# -------------------------
# Assignment
# -------------------------

func _assign_if_possible() -> void:
	_prune_invalid_sites()
	_prune_invalid_minions()

	# Iterate idle minions and give each one a job if possible
	for i in range(_idle_minions.size() - 1, -1, -1):
		var w := _idle_minions[i]
		var site := _pick_best_site_for_minion(w)
		if site == null:
			continue

		_idle_minions.remove_at(i)
		_reserve(site, w)

		w.assign_job(site)


func _pick_best_site_for_minion(minion: WorkSiteWorker) -> WorkSite:
	var best: WorkSite = null
	var best_score: float = INF

	for site in _sites:
		if not _site_needs_work(site):
			continue
		if one_minion_per_site and _is_reserved(site):
			continue

		# Optional site-side reservation rule
		if not bool(site.can_reserve(minion)):
			continue

		var wp := _get_site_pos(site)
		var d2 : float = minion.return_position().distance_squared_to(wp)
		if d2 < best_score:
			best_score = d2
			best = site

	return best


# -------------------------
# Internals
# -------------------------

func _reserve(site: WorkSite, minion: WorkSiteWorker) -> void:
	_reserved_by[site] = minion
	site.reserve(minion)


func _release_site(site: WorkSite) -> void:
	if _reserved_by.has(site):
		var w = _reserved_by[site]
		_reserved_by.erase(site)
		if is_instance_valid(site):
			site.unreserve(w)


func _is_reserved(site: WorkSite) -> bool:
	return _reserved_by.has(site) and is_instance_valid(_reserved_by[site])


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


func _get_site_pos(site: WorkSite) -> Vector2:
	return site.get_work_position()
