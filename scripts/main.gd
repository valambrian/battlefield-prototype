extends Control

var battlefield_grid: Node
var btn_add_rows: Button
var btn_remove_rows: Button
var btn_add_cols: Button
var btn_remove_cols: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dm := get_node("/root/DragManager")

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# --- Battlefield area (65%) ---
	var bf_area := Control.new()
	bf_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bf_area.size_flags_stretch_ratio = 6.5
	bf_area.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(bf_area)

	battlefield_grid = load("res://scenes/battlefield_grid.tscn").instantiate()
	battlefield_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bf_area.add_child(battlefield_grid)

	# --- Control buttons area ---
	var ctrl_bg := Panel.new()
	ctrl_bg.custom_minimum_size = Vector2(0, 56)
	ctrl_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ctrl_style := StyleBoxFlat.new()
	ctrl_style.bg_color = Color(0.06, 0.06, 0.12)
	ctrl_bg.add_theme_stylebox_override("panel", ctrl_style)
	vbox.add_child(ctrl_bg)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctrl_bg.add_child(hbox)

	btn_remove_rows = Button.new()
	btn_remove_rows.text = "- Rows"
	hbox.add_child(btn_remove_rows)

	btn_add_rows = Button.new()
	btn_add_rows.text = "+ Rows"
	hbox.add_child(btn_add_rows)

	btn_remove_cols = Button.new()
	btn_remove_cols.text = "- Column"
	hbox.add_child(btn_remove_cols)

	btn_add_cols = Button.new()
	btn_add_cols.text = "+ Column"
	hbox.add_child(btn_add_cols)

	btn_add_rows.pressed.connect(_on_add_rows)
	btn_remove_rows.pressed.connect(_on_remove_rows)
	btn_add_cols.pressed.connect(_on_add_cols)
	btn_remove_cols.pressed.connect(_on_remove_cols)

	# --- Tray area (25%) ---
	var tray_area := Control.new()
	tray_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_area.size_flags_stretch_ratio = 2.5
	vbox.add_child(tray_area)

	var unit_tray = load("res://scenes/unit_tray.tscn").instantiate()
	unit_tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tray_area.add_child(unit_tray)

	# --- Drag layer (renders above everything) ---
	var drag_layer := Control.new()
	drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(drag_layer)

	dm.drag_layer = drag_layer

	battlefield_grid.grid_changed.connect(_update_buttons)
	_update_buttons()


func _update_buttons() -> void:
	btn_add_rows.disabled = battlefield_grid.rows >= battlefield_grid.MAX_ROWS
	btn_remove_rows.disabled = battlefield_grid.rows <= battlefield_grid.MIN_ROWS
	btn_add_cols.disabled = battlefield_grid.cols >= battlefield_grid.MAX_COLS
	btn_remove_cols.disabled = battlefield_grid.cols <= battlefield_grid.MIN_COLS


func _on_add_rows() -> void:
	battlefield_grid.add_rows()
	_update_buttons()


func _on_remove_rows() -> void:
	battlefield_grid.remove_rows()
	_update_buttons()


func _on_add_cols() -> void:
	battlefield_grid.add_cols()
	_update_buttons()


func _on_remove_cols() -> void:
	battlefield_grid.remove_cols()
	_update_buttons()


func _input(event: InputEvent) -> void:
	var dm := get_node("/root/DragManager")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_RIGHT:
			dm.hide_tooltip()
	if not dm.is_dragging:
		return
	if event is InputEventMouseMotion:
		dm.update_drag(get_global_mouse_position())
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_handle_drop()


func _get_cell_at(pos: Vector2) -> Node:
	for row in battlefield_grid.cells:
		for cell in row:
			var rect := Rect2(cell.global_position, cell.size)
			if rect.has_point(pos):
				return cell
	return null


func _handle_drop() -> void:
	var dm := get_node("/root/DragManager")
	var mouse_pos := get_global_mouse_position()
	var drop_cell = _get_cell_at(mouse_pos)
	var src_cell = dm.source_cell
	var data: Dictionary = dm.unit_data.duplicate()
	var texture: Texture2D = dm.drag_texture

	dm.end_drag()

	# Clear any lingering highlights
	for row in battlefield_grid.cells:
		for cell in row:
			cell.set_highlight(false)

	if drop_cell == null:
		# Dropped outside grid — destroy unit
		if src_cell != null:
			src_cell.clear_unit()
		return

	if src_cell != null and drop_cell == src_cell:
		# Dropped on own cell — snap back
		src_cell.restore_display()
		return

	# Place on target cell (replaces any occupant)
	drop_cell.place_unit(data, texture)

	# Vacate source cell
	if src_cell != null:
		src_cell.clear_unit()
