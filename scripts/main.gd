extends Control

# ── Node references ───────────────────────────────────────────────────────────
var _battlefield_grid: Node
var _unit_tray: Node
var _fight_btn: Button
var _phase_label: Label
var _turn_label: Label
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _setup_controls: Control
var _btn_add_rows: Button
var _btn_remove_rows: Button
var _btn_add_cols: Button
var _btn_remove_cols: Button
var _victory_banner: Panel
var _targeting_overlay: Control

# ── Targeting state ───────────────────────────────────────────────────────────
var _selected_attacker_id: int = -1
var _targeting_lines: Array = []


func _ready() -> void:
	name = "Main"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var gs_ready: GameStateClass = get_node("/root/GameState")
	gs_ready.log_entry_added.connect(_on_log_entry)
	_update_ui()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	root_vbox.add_child(_make_header())
	root_vbox.add_child(_make_log_panel())

	_battlefield_grid = load("res://scenes/battlefield_grid.tscn").instantiate()
	_battlefield_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_battlefield_grid)

	_setup_controls = _make_setup_controls()
	root_vbox.add_child(_setup_controls)
	_update_resize_buttons()

	_unit_tray = load("res://scenes/unit_tray.tscn").instantiate()
	_unit_tray.custom_minimum_size = Vector2(0, 112)
	root_vbox.add_child(_unit_tray)

	root_vbox.add_child(_make_fight_bar())

	# Full-screen overlay for targeting lines and drag ghost
	_targeting_overlay = Control.new()
	_targeting_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_targeting_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_targeting_overlay.draw.connect(_draw_targeting_lines)
	add_child(_targeting_overlay)

	var dm_init: DragManagerClass = get_node("/root/DragManager")
	dm_init.drag_layer = _targeting_overlay

	_victory_banner = _make_victory_banner()
	_victory_banner.visible = false
	add_child(_victory_banner)


func _make_header() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 36)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.14)
	panel.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	_phase_label = Label.new()
	_phase_label.text = "Setup"
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.modulate = Color(1.0, 0.9, 0.5)
	hbox.add_child(_phase_label)

	_turn_label = Label.new()
	_turn_label.text = ""
	_turn_label.add_theme_font_size_override("font_size", 13)
	_turn_label.modulate = Color(0.7, 0.8, 1.0)
	hbox.add_child(_turn_label)

	return panel


func _make_log_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 72)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.10)
	bg.border_width_bottom = 1
	bg.border_color = Color(0.3, 0.3, 0.5, 0.6)
	panel.add_theme_stylebox_override("panel", bg)

	_log_scroll = ScrollContainer.new()
	_log_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_log_scroll)

	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 1)
	_log_scroll.add_child(_log_box)

	return panel


func _make_setup_controls() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 48)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12)
	panel.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	_btn_remove_rows = Button.new(); _btn_remove_rows.text = "− Rows"
	_btn_add_rows    = Button.new(); _btn_add_rows.text    = "+ Rows"
	_btn_remove_cols = Button.new(); _btn_remove_cols.text = "− Column"
	_btn_add_cols    = Button.new(); _btn_add_cols.text    = "+ Column"

	hbox.add_child(_btn_remove_rows)
	hbox.add_child(_btn_add_rows)
	hbox.add_child(_btn_remove_cols)
	hbox.add_child(_btn_add_cols)

	_btn_add_rows.pressed.connect(func():
		_battlefield_grid.add_rows(); _update_resize_buttons())
	_btn_remove_rows.pressed.connect(func():
		_battlefield_grid.remove_rows(); _update_resize_buttons())
	_btn_add_cols.pressed.connect(func():
		_battlefield_grid.add_cols(); _update_resize_buttons())
	_btn_remove_cols.pressed.connect(func():
		_battlefield_grid.remove_cols(); _update_resize_buttons())

	_battlefield_grid.grid_changed.connect(_update_resize_buttons)

	return panel


func _make_fight_bar() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 48)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12)
	panel.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	_fight_btn = Button.new()
	_fight_btn.text = "Start Battle"
	_fight_btn.custom_minimum_size = Vector2(170, 32)
	_fight_btn.pressed.connect(_on_fight_pressed)
	hbox.add_child(_fight_btn)

	return panel


func _make_victory_banner() -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(320, 100)
	panel.position = Vector2(480, 300)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.15, 0.95)
	bg.border_width_left = 2; bg.border_width_top = 2
	bg.border_width_right = 2; bg.border_width_bottom = 2
	bg.border_color = Color(0.8, 0.7, 0.2)
	panel.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.name = "BannerLabel"
	lbl.text = "Victory!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = Color(1.0, 0.9, 0.3)
	vbox.add_child(lbl)

	return panel


# ── Fight button ──────────────────────────────────────────────────────────────

func _on_fight_pressed() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	get_node("/root/DragManager").hide_tooltip()

	if gs.app_mode == gs.AppMode.SETUP:
		_start_combat()
		return
	if gs.winner != -1:
		_restart()
		return

	match gs.phase:
		3, 4, 5:  _execute_combat_phase()
		8:        _confirm_movement()


# ── Phase transitions ─────────────────────────────────────────────────────────

func _start_combat() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.app_mode = gs.AppMode.COMBAT
	gs.turn = 1
	gs.phase = 1
	gs.sub_step = "auto"
	gs.winner = -1
	gs.log_entries = []
	_clear_log()
	_sync_unit_coords_from_cells()
	_setup_controls.visible = false
	_unit_tray.visible = false
	_update_ui()


func _execute_phase1_and_advance() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.reset_support_bonuses()
	gs.apply_row_collapse(0)
	gs.apply_row_collapse(1)
	_battlefield_grid.sync_from_game_state()
	_advance_to_next_interactive_phase()


func _advance_to_next_interactive_phase() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	for p in [3, 4, 5]:
		if not gs.get_active_units_for_phase(p).is_empty():
			gs.phase = p
			gs.sub_step = "targeting"
			_setup_targeting_mode()
			_update_ui()
			return
	gs.phase = 7
	gs.sub_step = "auto"
	_update_ui()


func _execute_combat_phase() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.add_log("── %s Phase  (Turn %d) ──" % [gs.PHASE_NAMES[gs.phase], gs.turn])

	if gs.phase == 5:
		gs.compute_support_bonuses()

	for line in CombatResolver.resolve_phase(gs, gs.phase):
		gs.add_log(line)

	gs.clear_targets()
	_clear_targeting_mode()

	var v: int = gs.check_victory()
	if v != -1:
		_show_victory(v)
		return

	var next_p: int = gs.get_next_phase_after(gs.phase)
	gs.phase = next_p
	if next_p in [3, 4, 5]:
		gs.sub_step = "targeting"
		_setup_targeting_mode()
	else:
		gs.sub_step = "auto"
	_update_ui()


func _execute_phase7_and_advance() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.add_log("── Cleanup  (Turn %d) ──" % gs.turn)

	var to_remove: Array = []
	for u in gs.units:
		if u["combatants"].is_empty():
			to_remove.append(u)
	for u in to_remove:
		var ut: Dictionary = gs.get_unit_type(u["type_id"])
		gs.add_log("  %s (Side %d) destroyed." % [ut.get("name", "?"), u["side"]])
		gs.remove_unit(u["id"])

	_battlefield_grid.sync_from_game_state()

	var v: int = gs.check_victory()
	if v != -1:
		_show_victory(v)
		return

	gs.phase = 8
	gs.sub_step = "movement"
	_update_ui()


func _confirm_movement() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	_sync_unit_coords_from_cells()
	gs.turn += 1
	gs.phase = 1
	gs.sub_step = "auto"
	_update_ui()


func _restart() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.full_reset()
	_victory_banner.visible = false
	_clear_log()
	_clear_targeting_mode()
	_setup_controls.visible = true
	_unit_tray.visible = true
	_battlefield_grid._build_all()
	_update_ui()


# ── Targeting ─────────────────────────────────────────────────────────────────

func _setup_targeting_mode() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	_selected_attacker_id = -1
	for u in gs.get_active_units_for_phase(gs.phase):
		if u.get("assigned_target_id") == null:
			_selected_attacker_id = u["id"]
			break
	_battlefield_grid.apply_targeting_visuals(_selected_attacker_id)
	_refresh_targeting_lines()


func _clear_targeting_mode() -> void:
	_selected_attacker_id = -1
	_targeting_lines = []
	_battlefield_grid.clear_all_visual_states()
	_targeting_overlay.queue_redraw()


func on_cell_clicked(cell) -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if cell.is_empty():
		return
	var uid: int = cell.placed_unit_id
	var active_ids: Array = gs.get_active_units_for_phase(gs.phase).map(func(u): return u["id"])

	if _selected_attacker_id != -1:
		var sel: Dictionary = gs.get_unit(_selected_attacker_id)
		if not sel.is_empty() and cell.side != sel["side"]:
			# Enemy cell — assign as target
			sel["assigned_target_id"] = uid
			# Advance to next unassigned attacker
			_selected_attacker_id = -1
			for u in gs.get_active_units_for_phase(gs.phase):
				if u.get("assigned_target_id") == null:
					_selected_attacker_id = u["id"]
					break
		elif active_ids.has(uid):
			# Own-side active unit — switch selected attacker
			_selected_attacker_id = uid
	elif active_ids.has(uid):
		_selected_attacker_id = uid

	_battlefield_grid.apply_targeting_visuals(_selected_attacker_id)
	_refresh_targeting_lines()
	_update_fight_button()


func _refresh_targeting_lines() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	_targeting_lines = []
	for u in gs.units:
		var tid = u.get("assigned_target_id")
		if tid == null or u["row"] == null:
			continue
		var t: Dictionary = gs.get_unit(tid)
		if t.is_empty() or t["row"] == null:
			continue
		var fp: Vector2 = _battlefield_grid.get_cell_center_global(u["side"], u["row"], u["column"])
		var tp: Vector2 = _battlefield_grid.get_cell_center_global(t["side"], t["row"], t["column"])
		var x_offset: float = 18.0 if u["side"] == 0 else -18.0
		fp.x += x_offset
		tp.x += x_offset
		if fp != Vector2.ZERO and tp != Vector2.ZERO:
			_targeting_lines.append({
				"from": fp, "to": tp,
				"selected": u["id"] == _selected_attacker_id
			})
	_targeting_overlay.queue_redraw()


func _draw_targeting_lines() -> void:
	for e in _targeting_lines:
		var col: Color = Color(1.0, 1.0, 0.0, 0.9) if e["selected"] else Color(1.0, 0.5, 0.1, 0.7)
		var efrom: Vector2 = e["from"]
		var eto: Vector2 = e["to"]
		_targeting_overlay.draw_line(efrom, eto, col, 2.0)
		var d: Vector2 = (eto - efrom).normalized()
		var perp: Vector2 = Vector2(-d.y, d.x) * 5.0
		var tip: Vector2 = eto - d * 6.0
		_targeting_overlay.draw_line(eto, tip + perp, col, 2.0)
		_targeting_overlay.draw_line(eto, tip - perp, col, 2.0)


# ── UI helpers ────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	_update_fight_button()
	_update_header()
	var gs_ui: GameStateClass = get_node("/root/GameState")
	if gs_ui.app_mode == gs_ui.AppMode.COMBAT and gs_ui.winner == -1:
		if gs_ui.phase == 1 or gs_ui.phase == 7:
			call_deferred("_auto_execute_current_phase")


func _auto_execute_current_phase() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	match gs.phase:
		1: _execute_phase1_and_advance()
		7: _execute_phase7_and_advance()


func _update_header() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.app_mode == gs.AppMode.SETUP:
		_phase_label.text = "Setup"
		_turn_label.text = ""
	else:
		_phase_label.text = gs.PHASE_NAMES.get(gs.phase, "?")
		_turn_label.text = "Turn %d" % gs.turn


func _update_fight_button() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.winner != -1:
		_fight_btn.text = "Restart"; _fight_btn.disabled = false; return
	if gs.app_mode == gs.AppMode.SETUP:
		_fight_btn.text = "Start Battle"; _fight_btn.disabled = false; return
	match gs.phase:
		3, 4, 5:
			_fight_btn.text = "Resolve Phase"
			_fight_btn.disabled = not gs.all_targets_assigned()
		8: _fight_btn.text = "Confirm Movement";   _fight_btn.disabled = false
		_: _fight_btn.disabled = true


func _update_resize_buttons() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	_btn_add_rows.disabled    = gs.config["rows"] >= _battlefield_grid.MAX_ROWS
	_btn_remove_rows.disabled = gs.config["rows"] <= _battlefield_grid.MIN_ROWS
	_btn_add_cols.disabled    = gs.config["columns"] >= _battlefield_grid.MAX_COLS
	_btn_remove_cols.disabled = gs.config["columns"] <= _battlefield_grid.MIN_COLS


func _show_victory(winner: int) -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	gs.winner = winner
	_victory_banner.get_node("VBoxContainer/BannerLabel").text = "Side %d Wins!" % winner
	_victory_banner.visible = true
	_clear_targeting_mode()
	_update_fight_button()


func _on_log_entry(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if text.begins_with("──"):
		lbl.modulate = Color(0.9, 0.8, 0.4)
	elif "CRIT" in text:
		lbl.modulate = Color(1.0, 0.7, 0.3)
	elif "miss" in text:
		lbl.modulate = Color(0.5, 0.5, 0.6)
	elif "killed" in text:
		lbl.modulate = Color(1.0, 0.4, 0.4)
	else:
		lbl.modulate = Color(0.8, 0.85, 1.0)
	_log_box.add_child(lbl)
	_log_scroll.call_deferred("set_v_scroll", 999999)


func _clear_log() -> void:
	for c in _log_box.get_children():
		c.queue_free()


# ── Input (drag/drop) ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var dm: DragManagerClass = get_node("/root/DragManager")
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


func _handle_drop() -> void:
	var dm: DragManagerClass = get_node("/root/DragManager")
	var gs: GameStateClass = get_node("/root/GameState")
	var mouse_pos := get_global_mouse_position()

	var drop_cell: Object = _battlefield_grid.get_cell_at_pos(mouse_pos)
	var drop_reserve_side: int = _battlefield_grid.get_reserve_side_at_pos(mouse_pos)

	var src_cell: Object = dm.source_cell
	var src_reserve_side: int = dm.source_reserve_side
	var dragged_uid: int = dm.unit_id
	var dragged_type_id: int = dm.unit_type_id
	var texture: Texture2D = dm.drag_texture

	dm.end_drag()

	# Clear drop highlights
	for s in [0, 1]:
		for row_arr in _battlefield_grid.cells[s]:
			for cell in row_arr:
				cell.set_highlight(false)

	# ── Combat Phase 8 ───────────────────────────────────────────────────────
	if gs.app_mode == gs.AppMode.COMBAT:
		if gs.phase != 8 or dragged_uid == -1:
			if src_cell != null: src_cell.restore_display()
			return

		var drag_unit: Dictionary = gs.get_unit(dragged_uid)
		var drag_side: int = drag_unit.get("side", -1)

		if drop_cell != null and drop_cell.side == drag_side:
			if src_cell != null and drop_cell == src_cell:
				src_cell.restore_display()
				return
			if not drop_cell.is_empty():
				# Swap
				var other_uid: int = drop_cell.placed_unit_id
				var other_tex: Texture2D = drop_cell.get_cached_texture()
				drop_cell.place_unit(dragged_uid, texture)
				gs.move_unit(dragged_uid, drop_cell.game_row, drop_cell.game_col)
				if src_cell != null:
					src_cell.place_unit(other_uid, other_tex)
					gs.move_unit(other_uid, src_cell.game_row, src_cell.game_col)
				else:
					gs.move_unit(other_uid, null, null)
					_battlefield_grid.rebuild_reserve(drag_side)
			else:
				drop_cell.place_unit(dragged_uid, texture)
				gs.move_unit(dragged_uid, drop_cell.game_row, drop_cell.game_col)
				if src_cell != null:
					src_cell.clear_unit()
				elif src_reserve_side != -1:
					_battlefield_grid.rebuild_reserve(drag_side)
		elif drop_reserve_side == drag_side:
			gs.move_unit(dragged_uid, null, null)
			if src_cell != null: src_cell.clear_unit()
			_battlefield_grid.rebuild_reserve(drag_side)
		else:
			if src_cell != null: src_cell.restore_display()
		return

	# ── Setup mode ────────────────────────────────────────────────────────────

	# Drop onto reserve
	if drop_cell == null and drop_reserve_side != -1:
		if dragged_uid == -1:
			var new_u: Dictionary = gs.create_placed_unit(dragged_type_id, drop_reserve_side, null, null)
			if not new_u.is_empty():
				_battlefield_grid.rebuild_reserve(drop_reserve_side)
		else:
			gs.move_unit(dragged_uid, null, null)
			if src_cell != null: src_cell.clear_unit()
			_battlefield_grid.rebuild_reserve(drop_reserve_side if src_reserve_side == -1 else src_reserve_side)
		return

	# Drop outside grid and reserve — destroy
	if drop_cell == null:
		if dragged_uid != -1:
			gs.remove_unit(dragged_uid)
			if src_reserve_side != -1:
				_battlefield_grid.rebuild_reserve(src_reserve_side)
		return

	# Drop onto own cell — snap back
	if src_cell != null and drop_cell == src_cell:
		src_cell.restore_display()
		return

	# Remove existing occupant
	if not drop_cell.is_empty():
		gs.remove_unit(drop_cell.placed_unit_id)
		drop_cell.clear_unit()

	if dragged_uid == -1:
		# From tray — create new instance
		var new_u: Dictionary = gs.create_placed_unit(dragged_type_id, drop_cell.side, drop_cell.game_row, drop_cell.game_col)
		if not new_u.is_empty():
			drop_cell.place_unit(new_u["id"], texture)
	else:
		drop_cell.place_unit(dragged_uid, texture)
		gs.move_unit(dragged_uid, drop_cell.game_row, drop_cell.game_col)
		var u: Dictionary = gs.get_unit(dragged_uid)
		if not u.is_empty():
			u["side"] = drop_cell.side
		if src_cell != null:
			src_cell.clear_unit()
		elif src_reserve_side != -1:
			_battlefield_grid.rebuild_reserve(src_reserve_side)


# ── Unit coord sync ───────────────────────────────────────────────────────────

func _sync_unit_coords_from_cells() -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	for s in [0, 1]:
		for row_arr in _battlefield_grid.cells[s]:
			for cell in row_arr:
				if not cell.is_empty():
					var u: Dictionary = gs.get_unit(cell.placed_unit_id)
					if not u.is_empty():
						u["row"] = cell.game_row
						u["column"] = cell.game_col
						u["side"] = cell.side
