extends Node

var is_dragging: bool = false
var unit_data: Dictionary = {}
var source_cell = null
var drag_visual: TextureRect = null
var drag_texture: Texture2D = null
var hovered_cell = null
var drag_layer: Control = null

var _tooltip: PanelContainer = null


func show_tooltip(unit_name: String, pos: Vector2) -> void:
	hide_tooltip()
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.7, 0.7, 1.0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_tooltip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = unit_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(label)

	drag_layer.add_child(_tooltip)

	# Offset from cursor; clamp to stay on screen
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


func start_drag(data: Dictionary, texture: Texture2D, from_cell = null) -> void:
	is_dragging = true
	unit_data = data.duplicate()
	drag_texture = texture
	source_cell = from_cell
	hovered_cell = from_cell  # initialise so immediate release snaps back

	drag_visual = TextureRect.new()
	drag_visual.texture = texture
	drag_visual.custom_minimum_size = Vector2(48, 48)
	drag_visual.size = Vector2(48, 48)
	drag_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.add_child(drag_visual)


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
	unit_data = {}
