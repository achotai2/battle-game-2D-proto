@tool
extends Resource

# Array of dictionaries:
# {
#   "color": Color,
#   "slope_min": float,
#   "slope_max": float,
#   "height_min": float,
#   "height_max": float,
#   "density": float,
#   "name": String
# }
var _brushes := []

func _get_property_list() -> Array:
	return [
		{
			"name": "brushes",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE
		}
	]

func _get(key: StringName):
	if key == &"brushes":
		return _brushes

func _set(key: StringName, value):
	if key == &"brushes":
		_brushes = value
		emit_changed()

func add_brush(color: Color):
	_brushes.append({
		"color": color,
		"slope_min": 0.0,
		"slope_max": 90.0,
		"height_min": -10000.0,
		"height_max": 10000.0,
		"density": 1.0,
		"name": "New Color"
	})
	emit_changed()

func remove_brush(index: int):
	if index >= 0 and index < len(_brushes):
		_brushes.remove_at(index)
		emit_changed()

func get_brush_count() -> int:
	return len(_brushes)

func get_brush(index: int) -> Dictionary:
	if index >= 0 and index < len(_brushes):
		return _brushes[index]
	return {}

func set_brush_param(index: int, param: String, value):
	if index >= 0 and index < len(_brushes):
		var brush = _brushes[index]
		if brush.has(param) and brush[param] != value:
			brush[param] = value
			emit_changed()

func get_brush_param(index: int, param: String):
	if index >= 0 and index < len(_brushes):
		var brush = _brushes[index]
		if brush.has(param):
			return brush[param]
	return null
