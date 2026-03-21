extends Node
class_name WorkAction

var _last_work_time: int = 0
var animate: AgentAnimate = null
var work_interval: float = 1.0
var work_amount: float = 1.0


func _ready() -> void:
	pass

func deactivate() -> void:
	pass

func activate() -> void:
	if not animate:
		var base = ComponentFinder.get_base(self)
		animate = base.get("animate")


func do_work(_site: Node3D) -> void:
	var now = Time.get_ticks_msec()
	var interval_ms = int(work_interval * 1000)
	if now - _last_work_time >= interval_ms:
		_perform_work_tick(_site)
		_last_work_time = now


func _perform_work_tick(_site: Node3D) -> void:
	if animate:
		animate.play_work()

	if not _site or not _site.needs_work():
		return

	_site.apply_work(work_amount, ComponentFinder.get_base(self))
