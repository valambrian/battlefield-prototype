extends Panel

const SLOT_SIZE = 48
const COLS_PER_ROW = 20

var _unit_types: Array = []
var _asset_map: Dictionary = {}


func _ready() -> void:
	_load_data()
	_build_tray()


func _load_data() -> void:
	var file := FileAccess.open("res://assets/data/common.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_unit_types = parsed["units"]

	var file2 := FileAccess.open("res://assets/data/assets.json", FileAccess.READ)
	var assets_list = JSON.parse_string(file2.get_as_text())
	file2.close()
	for entry in assets_list:
		_asset_map[entry["name"]] = entry


func _build_tray() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.18)
	add_theme_stylebox_override("panel", bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	for row_idx in range(2):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		vbox.add_child(hbox)

		var start := row_idx * COLS_PER_ROW
		var end := mini(start + COLS_PER_ROW, _unit_types.size())
		for i in range(start, end):
			hbox.add_child(_create_slot(_unit_types[i]))


func _create_slot(unit_type: Dictionary) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.28)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.7, 0.7)
	slot.add_theme_stylebox_override("panel", style)

	var unit_name: String = unit_type.get("name", "")
	if _asset_map.has(unit_name):
		var asset: Dictionary = _asset_map[unit_name]
		var sheet: Texture2D = load("res://assets/sprites/units/" + asset["image"])
		if sheet:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(asset["x"], asset["y"], asset["width"], asset["height"])

			var tex_rect := TextureRect.new()
			tex_rect.texture = atlas
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(tex_rect)

			slot.set_meta("unit_data", unit_type)
			slot.set_meta("atlas_texture", atlas)

	slot.gui_input.connect(_on_slot_gui_input.bind(slot))
	return slot


func _on_slot_gui_input(event: InputEvent, slot: Panel) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not slot.has_meta("unit_data"):
			return
		var dm := get_node("/root/DragManager")
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not dm.is_dragging:
				get_viewport().set_input_as_handled()
				dm.start_drag(
					slot.get_meta("unit_data"),
					slot.get_meta("atlas_texture"),
					null
				)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			dm.show_tooltip(
				slot.get_meta("unit_data").get("name", ""),
				get_global_mouse_position()
			)
