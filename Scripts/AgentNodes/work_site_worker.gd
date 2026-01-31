extends Node
class_name WorkSiteWorker
## Base type for workers assigned by CastleJobBoard to WorkSite instances.
##
## WorkSiteWorker subclasses are expected to provide:
## - return_position(): Vector2
## - assign_job(site: WorkSite): void


func return_position() -> Vector2:
	return Vector2.ZERO


func assign_job(_site: WorkSite) -> void:
	pass
