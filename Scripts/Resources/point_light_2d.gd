extends PointLight2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Sun.sunset.is_connected(_is_night_time):
		Sun.sunset.connect(_is_night_time)
	if not Sun.sunrise.is_connected(_is_day_time):
		Sun.sunrise.connect(_is_day_time)


func _is_night_time() -> void:
	enabled = true


func _is_day_time() -> void:
	enabled = false
