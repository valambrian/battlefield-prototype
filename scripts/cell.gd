extends Panel

const CELL_SIZE = 72
const IMAGE_SIZE = 48

enum VisualState { NORMAL, ACTIVE_ATTACKER, SELECTED_ATTACKER, IS_TARGET }

var side: int = 0
var game_row: int = 1
var game_col: int = 1
var placed_unit_id: int = -1

var _texture: Texture2D = null
var _visual_state: int = VisualState.NORMAL
var _unit_display: TextureRect
var _count_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	size = Vector2(CELL_SIZE, CELL_SIZE)

	_unit_display = TextureRect.new()
	_unit_display.position = Vector2((CELL_SIZE - IMAGE_SIZE) / 2.0, (CELL_SIZE - IMAGE_SIZE) / 2.0)
	_unit_display.size = Vector2(IMAGE_SIZE, IMAGE_SIZE)
	_unit_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_display.visible = false
	add_child(_unit_display)

	_count_label = Label.new()
	_count_label.position = Vector2(CELL_SIZE - 18, CELL_SIZE - 14)
	_count_label.size = Vector2(18, 14)
	_count_label.add_theme_font_size_override("font_size", 9)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.visible = false
	add_child(_count_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	_refresh_style()


func is_empty() -> bool:
	return placed_unit_id == -1


func get_placed_unit() -> Dictionary:
	if placed_unit_id == -1:
		return {}
	return get_node("/root/GameState").get_unit(placed_unit_id)


func place_unit(uid: int, texture: Texture2D) -> void:
	placed_unit_id = uid
	_texture = texture
	_unit_display.texture = texture
	_unit_display.visible = true
	_update_count_label()
	_refresh_style()


func clear_unit() -> void:
	placed_unit_id = -1
	_texture = null
	_unit_display.texture = null
	_unit_display.visible = false
	_count_label.visible = false
	_refresh_style()


func restore_display() -> void:
	_unit_display.visible = true


func refresh_count() -> void:
	_update_count_label()


func get_cached_texture() -> Texture2D:
	return _texture


func set_visual_state(vs: int) -> void:
	_visual_state = vs
	_refresh_style()


func set_highlight(on: bool) -> void:
	if on:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.75, 0.75, 0.1, 0.9)
		s.border_width_left = 2; s.border_width_top = 2
		s.border_width_right = 2; s.border_width_bottom = 2
		s.border_color = Color(1.0, 1.0, 0.0)
		add_theme_stylebox_override("panel", s)
	else:
		_refresh_style()


func _update_count_label() -> void:
	if placed_unit_id == -1:
		_count_label.visible = false
		return
	var pu: Dictionary = get_placed_unit()
	if pu.is_empty():
		_count_label.visible = false
		return
	var count: int = pu["combatants"].size()
	if count > 0:
		_count_label.text = str(count)
		_count_label.visible = true
	else:
		_count_label.visible = false


func _refresh_style() -> void:
	var s := StyleBoxFlat.new()
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1

	match _visual_state:
		VisualState.ACTIVE_ATTACKER:
			s.bg_color = Color(0.55, 0.50, 0.05) if side == 0 else Color(0.05, 0.40, 0.50)
			s.border_color = Color(1.0, 0.9, 0.0)
			s.border_width_left = 2; s.border_width_top = 2
			s.border_width_right = 2; s.border_width_bottom = 2
		VisualState.SELECTED_ATTACKER:
			s.bg_color = Color(0.75, 0.65, 0.0) if side == 0 else Color(0.0, 0.55, 0.70)
			s.border_color = Color(1.0, 1.0, 0.2)
			s.border_width_left = 3; s.border_width_top = 3
			s.border_width_right = 3; s.border_width_bottom = 3
		VisualState.IS_TARGET:
			s.bg_color = Color(0.55, 0.12, 0.12)
			s.border_color = Color(1.0, 0.2, 0.2)
			s.border_width_left = 2; s.border_width_top = 2
			s.border_width_right = 2; s.border_width_bottom = 2
		_:  # NORMAL
			if side == 0:
				s.bg_color = Color(0.45, 0.15, 0.15) if is_empty() else Color(0.62, 0.28, 0.28)
			else:
				s.bg_color = Color(0.15, 0.15, 0.45) if is_empty() else Color(0.28, 0.28, 0.62)
			s.border_color = Color(0.6, 0.6, 0.8, 0.5)

	add_theme_stylebox_override("panel", s)


func _on_mouse_entered() -> void:
	var dm: DragManagerClass = get_node("/root/DragManager")
	if dm.is_dragging:
		set_highlight(true)
		dm.hovered_cell = self


func _on_mouse_exited() -> void:
	var dm: DragManagerClass = get_node("/root/DragManager")
	if dm.is_dragging and dm.hovered_cell == self:
		dm.hovered_cell = null
	if _visual_state == VisualState.NORMAL:
		set_highlight(false)
	else:
		_refresh_style()


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var dm: DragManagerClass = get_node("/root/DragManager")
	var gs: GameStateClass = get_node("/root/GameState")

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not is_empty():
			get_viewport().set_input_as_handled()
			_show_detail_tooltip(get_global_mouse_position())
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Targeting mode — dispatch to Main
	if gs.app_mode == gs.AppMode.COMBAT and gs.sub_step == "targeting":
		get_viewport().set_input_as_handled()
		get_tree().get_root().get_node("Main").on_cell_clicked(self)
		return

	# Drag: disallowed during combat except Phase 8
	if gs.app_mode == gs.AppMode.COMBAT and gs.phase != 8:
		return

	if not dm.is_dragging and not is_empty():
		get_viewport().set_input_as_handled()
		dm.start_drag_from_cell(self)
		_unit_display.visible = false


func _show_detail_tooltip(pos: Vector2) -> void:
	var gs: GameStateClass = get_node("/root/GameState")
	var pu: Dictionary = get_placed_unit()
	if pu.is_empty():
		return
	var ut: Dictionary = gs.get_unit_type(pu["type_id"])
	var text: String = ut.get("name", "?")
	text += "\nCombatants: %d" % pu["combatants"].size()

	var hp_map: Dictionary = {}
	for hp in pu["combatants"]:
		hp_map[hp] = hp_map.get(hp, 0) + 1
	var max_hp: int = ut.get("health", 1)
	var wounded: int = pu["combatants"].size() - hp_map.get(max_hp, 0)
	if wounded > 0:
		text += " (%d wounded)" % wounded

	for atk in ut.get("attacks", []):
		var q_names := _quality_names(atk.get("qualities", []))
		text += "\n  %s sk%d %s ×%d" % [
			q_names, atk.get("skill", 0), atk.get("damage", "?"), atk.get("quantity", 1)
		]

	get_node("/root/DragManager").show_tooltip(text, pos)


func _quality_names(qualities: Array) -> String:
	var names := {1:"Magic",2:"Gunpowder",3:"Ranged",4:"Skirmish",6:"Melee",7:"AP",8:"Fire",9:"Lightning"}
	var parts: Array = []
	for q in qualities:
		parts.append(names.get(q, "?"))
	return "/".join(parts)
