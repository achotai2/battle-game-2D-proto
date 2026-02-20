@tool
extends Control

signal brush_selected(index)
signal brush_added
signal brush_removed

const HTerrain = preload("../../hterrain.gd")
const HTerrainColorSet = preload("../../hterrain_color_set.gd")
const HT_Logger = preload("../../util/logger.gd")

var _terrain : HTerrain = null
var _color_set : HTerrainColorSet = null

var _brush_list : ItemList
var _add_button : Button
var _remove_button : Button

func _init():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_brush_list = ItemList.new()
	_brush_list.size_flags_vertical = SIZE_EXPAND_FILL
	_brush_list.item_selected.connect(_on_brush_selected)
	#_brush_list.max_columns = 0 # Auto
	_brush_list.icon_mode = ItemList.ICON_MODE_LEFT
	vbox.add_child(_brush_list)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	_add_button = Button.new()
	_add_button.text = "Add Color"
	_add_button.pressed.connect(_on_add_button_pressed)
	hbox.add_child(_add_button)

	_remove_button = Button.new()
	_remove_button.text = "Remove"
	_remove_button.pressed.connect(_on_remove_button_pressed)
	_remove_button.disabled = true
	hbox.add_child(_remove_button)

func set_terrain(terrain: HTerrain):
	if _terrain == terrain:
		return
	_terrain = terrain
	if _terrain != null:
		set_color_set(_terrain.get_color_set())
	else:
		set_color_set(null)

func set_color_set(color_set: HTerrainColorSet):
	if _color_set == color_set:
		return
	if _color_set != null:
		if _color_set.changed.is_connected(_update_list):
			_color_set.changed.disconnect(_update_list)

	_color_set = color_set

	if _color_set != null:
		if not _color_set.changed.is_connected(_update_list):
			_color_set.changed.connect(_update_list)

	_update_list()

func _update_list():
	_brush_list.clear()
	if _color_set == null:
		_add_button.disabled = true
		_remove_button.disabled = true
		return

	_add_button.disabled = false

	var count = _color_set.get_brush_count()
	for i in count:
		var brush = _color_set.get_brush(i)
		var color = brush.get("color", Color(1, 1, 1))
		var name = brush.get("name", "Color " + str(i))
		var icon = _create_color_icon(color)
		_brush_list.add_item(name, icon)

	if count > 0:
		if not _brush_list.is_any_selected():
			# Try to select the previous selection if possible?
			# For now just select first one if none selected
			# Or keep selection state? ItemList clears selection on clear()
			pass
	else:
		_remove_button.disabled = true

func _create_color_icon(color: Color) -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _on_brush_selected(index: int):
	_remove_button.disabled = false
	brush_selected.emit(index)

func _on_add_button_pressed():
	if _color_set != null:
		_color_set.add_brush(Color(1, 1, 1))
		brush_added.emit()
		# Select the new brush
		var count = _color_set.get_brush_count()
		_brush_list.select(count - 1)
		_on_brush_selected(count - 1)

func _on_remove_button_pressed():
	if _color_set != null:
		var selected = _brush_list.get_selected_items()
		if len(selected) > 0:
			var index = selected[0]
			_color_set.remove_brush(index)
			brush_removed.emit()
			# Select previous or next if available
			var count = _color_set.get_brush_count()
			if count > 0:
				var new_index = clampi(index, 0, count - 1)
				_brush_list.select(new_index)
				_on_brush_selected(new_index)
			else:
				_remove_button.disabled = true
