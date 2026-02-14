extends CanvasLayer

const WeatherControlScript = preload("res://Scripts/Weather/WorldEnvironmentControl.gd")

var weather_node: Node = null
var panel_container: PanelContainer

func _ready():
	# Find WeatherState node
	weather_node = get_tree().root.find_child("WeatherState", true, false)
	if not weather_node:
		push_error("DebugPanel: Could not find WeatherState node!")

	_build_ui()
	visible = false

func _build_ui():
	panel_container = PanelContainer.new()
	add_child(panel_container)

	# Center the panel
	panel_container.set_anchors_preset(Control.PRESET_CENTER)

	var vbox = VBoxContainer.new()
	panel_container.add_child(vbox)

	var title = Label.new()
	title.text = "Debug Panel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Weather State Buttons
	var weather_label = Label.new()
	weather_label.text = "Weather State"
	vbox.add_child(weather_label)

	var grid = GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)

	var states = {
		"Clear": WeatherControlScript.WeatherState.CLEAR,
		"Overcast": WeatherControlScript.WeatherState.OVERCAST,
		"Light Rain": WeatherControlScript.WeatherState.LIGHT_RAIN,
		"Storm": WeatherControlScript.WeatherState.STORM
	}

	for state_name in states:
		var btn = Button.new()
		btn.text = state_name
		btn.pressed.connect(_on_weather_btn_pressed.bind(states[state_name]))
		grid.add_child(btn)

	# Time of Day
	var time_label = Label.new()
	time_label.text = "Time of Day"
	vbox.add_child(time_label)

	var time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 1.0
	time_slider.step = 0.01
	time_slider.value = 0.3 # Default from script
	if weather_node:
		time_slider.value = weather_node.set_time_of_day
	time_slider.value_changed.connect(_on_time_slider_changed)
	vbox.add_child(time_slider)

	# Pause Day Cycle
	var pause_check = CheckButton.new()
	pause_check.text = "Pause Day Cycle"
	if weather_node:
		pause_check.button_pressed = weather_node.pause_day_cycle
	pause_check.toggled.connect(_on_pause_toggled)
	vbox.add_child(pause_check)

	# Transition Duration
	var trans_label = Label.new()
	trans_label.text = "Transition Duration"
	vbox.add_child(trans_label)

	var trans_slider = HSlider.new()
	trans_slider.min_value = 0.0
	trans_slider.max_value = 20.0
	trans_slider.step = 0.5
	if weather_node:
		trans_slider.value = weather_node.transition_duration
	trans_slider.value_changed.connect(_on_trans_slider_changed)
	vbox.add_child(trans_slider)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		visible = not visible
		get_viewport().set_input_as_handled()

func _on_weather_btn_pressed(state: int):
	if weather_node:
		weather_node.current_state = state

func _on_time_slider_changed(value: float):
	if weather_node:
		weather_node.set_time_of_day = value

func _on_pause_toggled(pressed: bool):
	if weather_node:
		weather_node.pause_day_cycle = pressed

func _on_trans_slider_changed(value: float):
	if weather_node:
		weather_node.transition_duration = value
