extends CanvasLayer

const WeatherControlScript = preload("res://Scripts/Weather/WorldEnvironmentControl.gd")

var weather_node: Node = null
var panel_container: PanelContainer

var selected_unit_type = null
var selected_player_id = 1
var unit_scene_map = {}
var selected_unit_label: Label
var selected_player_label: Label
var units_node: Node2D = null

func _ready():
	# Find WeatherState node
	weather_node = get_tree().root.find_child("WeatherState", true, false)
	if not weather_node:
		push_error("DebugPanel: Could not find WeatherState node!")

	units_node = get_tree().current_scene.find_child("Units", true, false)
	if not units_node:
		push_warning("DebugPanel: Could not find Units node!")

	_build_ui()
	visible = false

func _build_ui():
	panel_container = PanelContainer.new()
	add_child(panel_container)

	# Center the panel
	panel_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)

	var tab_container = TabContainer.new()
	panel_container.add_child(tab_container)

	# --- Weather Tab ---
	var weather_tab = VBoxContainer.new()
	weather_tab.name = "Weather"
	tab_container.add_child(weather_tab)

	var title = Label.new()
	title.text = "Weather Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_tab.add_child(title)

	# Weather State Buttons
	var weather_label = Label.new()
	weather_label.text = "Weather State"
	weather_tab.add_child(weather_label)

	var grid = GridContainer.new()
	grid.columns = 2
	weather_tab.add_child(grid)

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
	weather_tab.add_child(time_label)

	var time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 1.0
	time_slider.step = 0.01
	time_slider.value = 0.3 # Default from script
	if weather_node:
		time_slider.value = weather_node.set_time_of_day
	time_slider.value_changed.connect(_on_time_slider_changed)
	weather_tab.add_child(time_slider)

	# Pause Day Cycle
	var pause_check = CheckButton.new()
	pause_check.text = "Pause Day Cycle"
	if weather_node:
		pause_check.button_pressed = weather_node.pause_day_cycle
	pause_check.toggled.connect(_on_pause_toggled)
	weather_tab.add_child(pause_check)

	# Transition Duration
	var trans_label = Label.new()
	trans_label.text = "Transition Duration"
	weather_tab.add_child(trans_label)

	var trans_slider = HSlider.new()
	trans_slider.min_value = 0.0
	trans_slider.max_value = 20.0
	trans_slider.step = 0.5
	if weather_node:
		trans_slider.value = weather_node.transition_duration
	trans_slider.value_changed.connect(_on_trans_slider_changed)
	weather_tab.add_child(trans_slider)

	# --- Spawn Tab ---
	var spawn_tab = VBoxContainer.new()
	spawn_tab.name = "Spawn"
	tab_container.add_child(spawn_tab)

	var spawn_label = Label.new()
	spawn_label.text = "Spawn Units"
	spawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spawn_tab.add_child(spawn_label)

	# --- Player Selection ---
	var player_label = Label.new()
	player_label.text = "Select Player"
	spawn_tab.add_child(player_label)

	selected_player_label = Label.new()
	_update_player_label()
	spawn_tab.add_child(selected_player_label)

	var player_grid = GridContainer.new()
	player_grid.columns = 2
	spawn_tab.add_child(player_grid)

	var players = {
		"Neutral (0)": 0,
		"Player (1)": 1,
		"Enemy (2)": 2,
		"Random (1/2)": -1
	}

	for p_name in players:
		var btn = Button.new()
		btn.text = p_name
		btn.pressed.connect(_on_player_selected.bind(players[p_name]))
		player_grid.add_child(btn)

	# --- Unit Selection ---
	selected_unit_label = Label.new()
	selected_unit_label.text = "Selected Unit: None"
	spawn_tab.add_child(selected_unit_label)

	var spawn_grid = GridContainer.new()
	spawn_grid.columns = 4
	spawn_tab.add_child(spawn_grid)

	unit_scene_map = {
		UnitRoles.UnitType.PLAYER: "res://Scenes/Units/Player.tscn",
		UnitRoles.UnitType.PEASANT: "res://Scenes/Units/peasant.tscn",
		UnitRoles.UnitType.SOLDIER: "res://Scenes/Units/soldier.tscn",
		UnitRoles.UnitType.ARCHER: "res://Scenes/Units/archer.tscn",
		UnitRoles.UnitType.WORKER: "res://Scenes/Units/worker.tscn",
		UnitRoles.UnitType.LORD: "res://Scenes/Units/lord.tscn"
	}

	for unit_type in unit_scene_map:
		var btn = Button.new()
		var frames = UnitRoles.get_frames(unit_type, 1)
		var texture = null
		if frames:
			if frames.has_animation("idle"):
				texture = frames.get_frame_texture("idle", 0)
			elif frames.has_animation("walk"):
				texture = frames.get_frame_texture("walk", 0)
			elif frames.has_animation("default"):
				texture = frames.get_frame_texture("default", 0)

		if texture:
			btn.icon = texture
			btn.expand_icon = true
			btn.custom_minimum_size = Vector3(64, 0, 64)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			btn.text = str(unit_type)

		btn.pressed.connect(_on_unit_selected.bind(unit_type))
		spawn_grid.add_child(btn)

func _on_unit_selected(type):
	selected_unit_type = type
	var type_name = UnitRoles.UnitType.find_key(type)
	selected_unit_label.text = "Selected Unit: " + str(type_name)

func _on_player_selected(id: int):
	selected_player_id = id
	_update_player_label()

func _update_player_label():
	if selected_player_id == -1:
		selected_player_label.text = "Selected Player: Random (1 or 2)"
	else:
		selected_player_label.text = "Selected Player: " + str(selected_player_id)

func _unhandled_input(event):
	if not visible:
		return

	if not units_node:
		units_node = get_tree().current_scene.find_child("Units", true, false)
		if not units_node:
			return

	if event.is_action_pressed("click"):
		if selected_unit_type != null:
			var scene_path = unit_scene_map.get(selected_unit_type)
			if scene_path:
				var scene = load(scene_path)
				if scene:
					var instance = scene.instantiate()

					var pid = selected_player_id
					if pid == -1:
						pid = randi_range(1, 2)

					if "player" in instance:
						instance.player = pid

					units_node.add_child(instance)
					instance.global_position = units_node.get_global_mouse_position()
					get_viewport().set_input_as_handled()

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
