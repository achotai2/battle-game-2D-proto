extends DirectionalLight3D

func _ready() -> void:
	# Connect to the GlobalSun autoload
	if has_node("/root/Sun"):
		Sun.sun_updated.connect(_on_sun_updated)
		
		# Initialize color immediately so it doesn't pop in later
		light_color = Sun.color_night
	else:
		push_warning("Sunlight: Sun autoload not found!")

func _on_sun_updated(new_ambient: Color, _new_shadow: Color) -> void:
	light_color = new_ambient
