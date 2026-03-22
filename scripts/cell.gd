extends Panel

const CELL_SIZE = 64

var grid_row: int = 0
var grid_col: int = 0
var is_side_a: bool = false
var unit_data: Dictionary = {}
var unit_display: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	size = Vector2(CELL_SIZE, CELL_SIZE)

	unit_display = TextureRect.new()
	unit_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	unit_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	unit_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_display.visible = false
	add_child(unit_display)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	_refresh_style()


func is_empty() -> bool:
	return unit_data.is_empty()


func place_unit(data: Dictionary, texture: Texture2D) -> void:
	unit_data = data.duplicate()
	unit_display.texture = texture
	unit_display.visible = true
	_refresh_style()


func clear_unit() -> void:
	unit_data = {}
	unit_display.texture = null
	unit_display.visible = false
	_refresh_style()


func restore_display() -> void:
	unit_display.visible = true


func _refresh_style() -> void:
	var style := StyleBoxFlat.new()
	if is_side_a:
		style.bg_color = Color(0.45, 0.15, 0.15) if is_empty() else Color(0.62, 0.28, 0.28)
	else:
		style.bg_color = Color(0.15, 0.15, 0.45) if is_empty() else Color(0.28, 0.28, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.6, 0.6, 0.8, 0.5)
	add_theme_stylebox_override("panel", style)


func set_highlight(on: bool) -> void:
	if on:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.75, 0.75, 0.1, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 1.0, 0.0)
		add_theme_stylebox_override("panel", style)
	else:
		_refresh_style()


func _on_mouse_entered() -> void:
	var dm := get_node("/root/DragManager")
	if dm.is_dragging:
		set_highlight(true)
		dm.hovered_cell = self


func _on_mouse_exited() -> void:
	var dm := get_node("/root/DragManager")
	if dm.is_dragging and dm.hovered_cell == self:
		dm.hovered_cell = null
	set_highlight(false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var dm := get_node("/root/DragManager")
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not dm.is_dragging and not is_empty():
				get_viewport().set_input_as_handled()
				dm.start_drag(unit_data, unit_display.texture, self)
				unit_display.visible = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not is_empty():
				get_viewport().set_input_as_handled()
				dm.show_tooltip(unit_data.get("name", ""), get_global_mouse_position())
