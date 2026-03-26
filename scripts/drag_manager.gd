extends Node
class_name DragManagerClass

var is_dragging: bool = false
var drag_layer: Control = null
var drag_visual: TextureRect = null
var drag_texture: Texture2D = null
var hovered_cell = null       # Cell node or null

# Drag source info
var source_cell = null        # Cell node, null if from tray/reserve
var source_reserve_side: int = -1
var unit_id: int = -1         # -1 = from tray (no instance yet)
var unit_type_id: int = -1

# Texture cache by type_id, populated by unit_tray
var texture_cache: Dictionary = {}

var _tooltip: PanelContainer = null


func cache_texture(type_id: int, texture: Texture2D) -> void:
	texture_cache[type_id] = texture


func get_texture(type_id: int) -> Texture2D:
	return texture_cache.get(type_id, null)


func start_drag_from_tray(type_id: int, texture: Texture2D) -> void:
	hide_tooltip()
	is_dragging = true
	unit_id = -1
	unit_type_id = type_id
	source_cell = null
	source_reserve_side = -1
	drag_texture = texture
	hovered_cell = null
	_spawn_visual(texture)


func start_drag_from_cell(cell) -> void:
	hide_tooltip()
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.app_mode == gs.AppMode.COMBAT and gs.phase != 8:
		return
	is_dragging = true
	unit_id = cell.placed_unit_id
	var pu: Dictionary = gs.get_unit(unit_id)
	unit_type_id = pu.get("type_id", -1) if not pu.is_empty() else -1
	source_cell = cell
	source_reserve_side = -1
	drag_texture = cell.get_cached_texture()
	hovered_cell = cell
	_spawn_visual(drag_texture)


func start_drag_from_reserve(reserve_unit_id: int, reserve_side: int, texture: Texture2D) -> void:
	hide_tooltip()
	var gs: GameStateClass = get_node("/root/GameState")
	if gs.app_mode == gs.AppMode.COMBAT and gs.phase != 8:
		return
	is_dragging = true
	unit_id = reserve_unit_id
	var pu: Dictionary = gs.get_unit(reserve_unit_id)
	unit_type_id = pu.get("type_id", -1) if not pu.is_empty() else -1
	source_cell = null
	source_reserve_side = reserve_side
	drag_texture = texture
	hovered_cell = null
	_spawn_visual(texture)


func update_drag(pos: Vector2) -> void:
	if drag_visual:
		drag_visual.position = pos - drag_visual.size / 2.0


func end_drag() -> void:
	is_dragging = false
	if drag_visual:
		drag_visual.queue_free()
		drag_visual = null
	drag_texture = null
	hovered_cell = null
	source_cell = null
	source_reserve_side = -1
	unit_id = -1
	unit_type_id = -1


func _spawn_visual(texture: Texture2D) -> void:
	if drag_layer == null:
		return
	drag_visual = TextureRect.new()
	drag_visual.texture = texture
	drag_visual.custom_minimum_size = Vector2(48, 48)
	drag_visual.size = Vector2(48, 48)
	drag_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.add_child(drag_visual)


func show_tooltip(text: String, pos: Vector2) -> void:
	hide_tooltip()
	if drag_layer == null:
		return
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
	style.border_width_left = 1; style.border_width_top = 1
	style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.7, 0.7, 1.0)
	style.content_margin_left = 8; style.content_margin_right = 8
	style.content_margin_top = 4; style.content_margin_bottom = 4
	_tooltip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	_tooltip.add_child(label)

	drag_layer.add_child(_tooltip)
	var offset := Vector2(14, 14)
	var min_size := _tooltip.get_minimum_size()
	var vp := drag_layer.size
	_tooltip.position = Vector2(
		minf(pos.x + offset.x, vp.x - min_size.x),
		minf(pos.y + offset.y, vp.y - min_size.y)
	)


func hide_tooltip() -> void:
	if _tooltip:
		_tooltip.queue_free()
		_tooltip = null
