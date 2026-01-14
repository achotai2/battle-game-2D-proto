extends Node
class_name CastleJobBoard

@export var castle: Node2D
@export var one_worker_per_site: bool = true

var _sites: Array[WorkSite] = []
var _reserved_by: Dictionary = {} # site: worker

var _idle_workers: Array[TacticalWorker] = []


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
# Workers
# -------------------------

func register_worker(worker: TacticalWorker) -> void:
	if worker == null or not is_instance_valid(worker):
		return

	# Clean up if worker is freed
	worker.tree_exited.connect(_on_worker_exited.bind(worker), CONNECT_ONE_SHOT)


func unregister_worker(worker: TacticalWorker) -> void:
	# Remove from idle list if present
	var idx := _idle_workers.find(worker)
	if idx != -1:
		_idle_workers.remove_at(idx)

	# Release any reservations held by this worker
	for site in _reserved_by.keys():
		if _reserved_by.get(site) == worker:
			_release_site(site)

	_assign_if_possible()


func _on_worker_exited(worker: TacticalWorker) -> void:
	unregister_worker(worker)


func worker_idle(worker: TacticalWorker) -> void:
	if worker == null or not is_instance_valid(worker):
		return
	if not _idle_workers.has(worker):
		_idle_workers.append(worker)
	_assign_if_possible()


# Worker calls this when abandoning/completing a job
func release_job(site: WorkSite, worker: TacticalWorker) -> void:
	if site == null:
		return
	if _reserved_by.get(site) == worker:
		_release_site(site)
	_assign_if_possible()


# -------------------------
# Assignment
# -------------------------

func _assign_if_possible() -> void:
	_prune_invalid_sites()
	_prune_invalid_workers()

	# Iterate idle workers and give each one a job if possible
	for i in range(_idle_workers.size() - 1, -1, -1):
		var w := _idle_workers[i]
		var site := _pick_best_site_for_worker(w)
		if site == null:
			continue

		_idle_workers.remove_at(i)
		_reserve(site, w)

		w.assign_job(site)


func _pick_best_site_for_worker(worker: TacticalWorker) -> WorkSite:
	var best: WorkSite = null
	var best_score: float = INF

	for site in _sites:
		if not _site_needs_work(site):
			continue
		if one_worker_per_site and _is_reserved(site):
			continue

		# Optional site-side reservation rule
		if not bool(site.can_reserve(worker)):
			continue

		var wp := _get_site_pos(site)
		var d2 : float = worker.return_position().distance_squared_to(wp)
		if d2 < best_score:
			best_score = d2
			best = site

	return best


# -------------------------
# Internals
# -------------------------

func _reserve(site: WorkSite, worker: TacticalWorker) -> void:
	_reserved_by[site] = worker
	site.reserve(worker)


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


func _prune_invalid_workers() -> void:
	for i in range(_idle_workers.size() - 1, -1, -1):
		if _idle_workers[i] == null or not is_instance_valid(_idle_workers[i]):
			_idle_workers.remove_at(i)


func _site_needs_work(site: WorkSite) -> bool:
	return site.needs_work()


func _get_site_pos(site: WorkSite) -> Vector2:
	return site.get_work_position()
