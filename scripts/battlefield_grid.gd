extends Control

const MIN_ROWS = 2   # total rows (both sides), must be even
const MAX_ROWS = 8
const MIN_COLS = 1
const MAX_COLS = 12

const CellScene = preload("res://scenes/cell.tscn")

# cells[side][display_row][col_index]  (0-indexed col_index)
var cells: Array = [[], []]

var _vbox: VBoxContainer
var _reserve_boxes: Array = [null, null]
var _reserve_panels: Array = [null, null]
var _grid_containers: Array = [null, null]

signal grid_changed


func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 0)
	add_child(_vbox)
	_build_all()


# ── Build ─────────────────────────────────────────────────────────────────────

func _build_all() -> void:
	for c in _vbox.get_children():
		c.queue_free()
	cells = [[], []]

	var gs: GameStateClass = get_node("/root/GameState")
	var rps: int = gs.rows_per_side()
	var cols: int = gs.config["columns"]

	# Side 1 reserve (top)
	_reserve_panels[1] = _make_reserve_panel(1)
	_vbox.add_child(_reserve_panels[1])

	# Side 1 grid (Row 1 = front = bottom row of this grid)
	var center1 := CenterContainer.new()
	center1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vbox.add_child(center1)
	_grid_containers[1] = GridContainer.new()
	_grid_containers[1].columns = cols
	_grid_containers[1].add_theme_constant_override("h_separation", 0)
	_grid_containers[1].add_theme_constant_override("v_separation", 0)
	center1.add_child(_grid_containers[1])

	# Divider
	var div := Panel.new()
	div.custom_minimum_size = Vector2(0, 4)
	var div_style := StyleBoxFlat.new()
	div_style.bg_color = Color(0.8, 0.8, 0.9, 0.7)
	div.add_theme_stylebox_override("panel", div_style)
	_vbox.add_child(div)

	# Side 0 grid (Row 1 = front = top row of this grid)
	var center0 := CenterContainer.new()
	center0.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vbox.add_child(center0)
	_grid_containers[0] = GridContainer.new()
	_grid_containers[0].columns = cols
	_grid_containers[0].add_theme_constant_override("h_separation", 0)
	_grid_containers[0].add_theme_constant_override("v_separation", 0)
	center0.add_child(_grid_containers[0])

	# Side 0 reserve (bottom)
	_reserve_panels[0] = _make_reserve_panel(0)
	_vbox.add_child(_reserve_panels[0])

	_populate_cells(rps, cols)
	emit_signal("grid_changed")


func _make_reserve_panel(side: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 60)
	panel.set_meta("reserve_side", side)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.18)
	if side == 1:
		bg.border_width_bottom = 1
	else:
		bg.border_width_top = 1
	bg.border_color = Color(0.5, 0.5, 0.7, 0.4)
	panel.add_theme_stylebox_override("panel", bg)

	var hbox_outer := HBoxContainer.new()
	hbox_outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox_outer.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox_outer)

	var lbl := Label.new()
	lbl.text = "Reserve %d" % side
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.modulate = Color(0.6, 0.6, 0.8)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(68, 0)
	hbox_outer.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 52)
	hbox_outer.add_child(scroll)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(box)
	_reserve_boxes[side] = box

	return panel


func _populate_cells(rps: int, cols: int) -> void:
	cells = [[], []]
	for s in [0, 1]:
		cells[s] = []
		for dr in range(rps):
			var row_arr: Array = []
			for c in range(cols):
				var cell := CellScene.instantiate()
				cell.side = s
				cell.game_row = _display_to_game_row(s, dr, rps)
				cell.game_col = c + 1
				_grid_containers[s].add_child(cell)
				row_arr.append(cell)
			cells[s].append(row_arr)


# ── Row ↔ display conversion ──────────────────────────────────────────────────

# Side 0: display 0 = game row 1 (front, nearest divider)
# Side 1: display 0 = game row rps (rear), display rps-1 = game row 1 (front, nearest divider)
func _display_to_game_row(side: int, dr: int, rps: int) -> int:
	return (dr + 1) if side == 0 else (rps - dr)


func _game_to_display_row(side: int, game_row: int, rps: int) -> int:
	return (game_row - 1) if side == 0 else (rps - game_row)


# ── Public cell queries ───────────────────────────────────────────────────────

func get_cell(s: int, game_row: int, col: int) -> Object:
	var gs: GameStateClass = get_node("/root/GameState")
	var rps: int = gs.rows_per_side()
	var dr := _game_to_display_row(s, game_row, rps)
	if dr < 0 or dr >= cells[s].size():
		return null
	var ci := col - 1
	if ci < 0 or ci >= cells[s][dr].size():
		return null
	return cells[s][dr][ci]


func get_cell_center_global(s: int, game_row: int, col: int) -> Vector2:
	var cell := get_cell(s, game_row, col)
	if cell == null:
		return Vector2.ZERO
	return cell.global_position + cell.size / 2.0


func get_cell_at_pos(pos: Vector2) -> Object:
	for s in [0, 1]:
		for row_arr in cells[s]:
			for cell in row_arr:
				if Rect2(cell.global_position, cell.size).has_point(pos):
					return cell
	return null


func get_reserve_side_at_pos(pos: Vector2) -> int:
	for s in [0, 1]:
		if _reserve_panels[s] != null:
			if Rect2(_reserve_panels[s].global_position, _reserve_panels[s].size).has_point(pos):
				return s
	return -1


# ── Grid resize (setup mode only) ─────────────────────────────────────────────

func add_rows() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.config["rows"] >= MAX_ROWS:
		return
	var saved := _save_placed_units()
	gs.config["rows"] += 2
	_build_all()
	# New rows added at the rear; existing units keep their game_row
	for entry in saved:
		var cell := get_cell(entry["side"], entry["game_row"], entry["col"])
		if cell != null:
			cell.place_unit(entry["uid"], entry["texture"])
	emit_signal("grid_changed")


func remove_rows() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.config["rows"] <= MIN_ROWS:
		return
	var old_rps: int = gs.rows_per_side()
	var saved := _save_placed_units()
	# Remove units in the outermost row (rear = game_row old_rps)
	for entry in saved:
		if entry["game_row"] == old_rps:
			gs.remove_unit(entry["uid"])
	gs.config["rows"] -= 2
	var new_rps := gs.rows_per_side()
	_build_all()
	for entry in saved:
		if entry["game_row"] > new_rps:
			continue
		var cell := get_cell(entry["side"], entry["game_row"], entry["col"])
		if cell != null:
			cell.place_unit(entry["uid"], entry["texture"])
	emit_signal("grid_changed")


func add_cols() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.config["columns"] >= MAX_COLS:
		return
	var saved := _save_placed_units()
	gs.config["columns"] += 1
	_build_all()
	for entry in saved:
		var cell := get_cell(entry["side"], entry["game_row"], entry["col"])
		if cell != null:
			cell.place_unit(entry["uid"], entry["texture"])
	emit_signal("grid_changed")


func remove_cols() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.config["columns"] <= MIN_COLS:
		return
	var old_cols: int = gs.config["columns"]
	var saved := _save_placed_units()
	for entry in saved:
		if entry["col"] == old_cols:
			gs.remove_unit(entry["uid"])
	gs.config["columns"] -= 1
	_build_all()
	for entry in saved:
		if entry["col"] > gs.config["columns"]:
			continue
		var cell := get_cell(entry["side"], entry["game_row"], entry["col"])
		if cell != null:
			cell.place_unit(entry["uid"], entry["texture"])
	emit_signal("grid_changed")


func _save_placed_units() -> Array:
	var result: Array = []
	for s in [0, 1]:
		for row_arr in cells[s]:
			for cell in row_arr:
				if not cell.is_empty():
					result.append({
						"uid": cell.placed_unit_id,
						"side": s,
						"game_row": cell.game_row,
						"col": cell.game_col,
						"texture": cell.get_cached_texture()
					})
	return result


# ── Sync from GameState ───────────────────────────────────────────────────────

func sync_from_game_state() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	var rps: int = gs.rows_per_side()

	for s in [0, 1]:
		for row_arr in cells[s]:
			for cell in row_arr:
				cell.clear_unit()

	for u in gs.units:
		if u["row"] == null:
			continue
		var s: int = u["side"]
		var dr := _game_to_display_row(s, u["row"], rps)
		if dr < 0 or dr >= cells[s].size():
			continue
		var ci: int = u["column"] - 1
		if ci < 0 or ci >= cells[s][dr].size():
			continue
		var dm_sync: DragManagerClass = get_node("/root/DragManager")
		var texture: Texture2D = dm_sync.get_texture(u["type_id"])
		cells[s][dr][ci].place_unit(u["id"], texture)

	rebuild_reserve(0)
	rebuild_reserve(1)


func rebuild_reserve(side: int) -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	var box: HBoxContainer = _reserve_boxes[side]
	if box == null:
		return
	for c in box.get_children():
		c.queue_free()

	var reserve_units: Array = gs.get_units_in_reserve(side)
	var dm_res: DragManagerClass = get_node("/root/DragManager")
	for u in reserve_units:
		var texture: Texture2D = dm_res.get_texture(u["type_id"])
		box.add_child(_make_reserve_slot(u["id"], side, texture, gs))

	if reserve_units.is_empty():
		var lbl := Label.new()
		lbl.text = "(empty)"
		lbl.modulate = Color(0.4, 0.4, 0.5)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(lbl)


func _make_reserve_slot(uid: int, side: int, texture: Texture2D, gs: GameState) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(48, 48)
	slot.set_meta("unit_id", uid)
	slot.set_meta("side", side)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.10, 0.10) if side == 0 else Color(0.10, 0.10, 0.30)
	bg.border_width_left = 1; bg.border_width_top = 1
	bg.border_width_right = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.5, 0.5, 0.7, 0.5)
	slot.add_theme_stylebox_override("panel", bg)

	if texture != null:
		var trect := TextureRect.new()
		trect.texture = texture
		trect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(trect)

	var u: Dictionary = gs.get_unit(uid)
	var ut: Dictionary = gs.get_unit_type(u.get("type_id", -1))
	if ut.get("size", 1) > 1:
		var cnt_lbl := Label.new()
		cnt_lbl.text = str(u["combatants"].size())
		cnt_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cnt_lbl.position = Vector2(30, 34)
		cnt_lbl.size = Vector2(18, 14)
		cnt_lbl.add_theme_font_size_override("font_size", 9)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cnt_lbl)

	slot.gui_input.connect(_on_reserve_slot_input.bind(slot))
	return slot


func _on_reserve_slot_input(event: InputEvent, slot: Panel) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var dm: DragManagerClass = get_node("/root/DragManager")
	if dm.is_dragging:
		return
	get_viewport().set_input_as_handled()
	var uid: int = slot.get_meta("unit_id")
	var s: int = slot.get_meta("side")
	var gs_slot: GameStateClass = get_node("/root/GameState")
	var slot_unit: Dictionary = gs_slot.get_unit(uid)
	var texture: Texture2D = dm.get_texture(slot_unit.get("type_id", -1))
	dm.start_drag_from_reserve(uid, s, texture)


# ── Targeting visuals ─────────────────────────────────────────────────────────

func clear_all_visual_states() -> void:
	for s in [0, 1]:
		for row_arr in cells[s]:
			for cell in row_arr:
				cell.set_visual_state(0)  # NORMAL


func apply_targeting_visuals(selected_attacker_id: int) -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	var active: Array = gs.get_active_units_for_phase(gs.phase)
	var active_ids: Array = []
	for u in active:
		active_ids.append(u["id"])

	clear_all_visual_states()

	# Find which unit (if any) the selected attacker is targeting
	var sel_target_id: int = -1
	if selected_attacker_id != -1:
		var sel_u: Dictionary = gs.get_unit(selected_attacker_id)
		if not sel_u.is_empty():
			sel_target_id = sel_u.get("assigned_target_id", null) if sel_u.get("assigned_target_id") != null else -1

	for s in [0, 1]:
		for row_arr in cells[s]:
			for cell in row_arr:
				if cell.is_empty():
					continue
				var uid: int = cell.placed_unit_id
				if uid == selected_attacker_id:
					cell.set_visual_state(2)  # SELECTED_ATTACKER
				elif uid == sel_target_id:
					cell.set_visual_state(3)  # IS_TARGET
				elif active_ids.has(uid):
					cell.set_visual_state(1)  # ACTIVE_ATTACKER
