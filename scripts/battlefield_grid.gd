extends Control

const CELL_SIZE = 64
const MIN_ROWS = 2
const MAX_ROWS = 8
const MIN_COLS = 1
const MAX_COLS = 12
const CellScene = preload("res://scenes/cell.tscn")

var rows: int = 6
var cols: int = 6
var cells: Array = []
var grid_container: GridContainer

signal grid_changed


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	grid_container = GridContainer.new()
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	center.add_child(grid_container)

	_build_grid()


func _build_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	cells = []

	grid_container.columns = cols
	var half := rows / 2

	for r in range(rows):
		var row_arr: Array = []
		for c in range(cols):
			var cell: Panel = CellScene.instantiate()
			cell.grid_row = r
			cell.grid_col = c
			cell.is_side_a = r < half
			grid_container.add_child(cell)
			row_arr.append(cell)
		cells.append(row_arr)

	emit_signal("grid_changed")


func _save_units() -> Array:
	var saved: Array = []
	for r in range(cells.size()):
		for c in range(cells[r].size()):
			var cell = cells[r][c]
			if not cell.is_empty():
				saved.append({
					"row": r,
					"col": c,
					"unit_data": cell.unit_data.duplicate(),
					"texture": cell.unit_display.texture
				})
	return saved


func add_rows() -> void:
	if rows >= MAX_ROWS:
		return
	var saved := _save_units()
	rows += 2
	_build_grid()
	# Shift all units down by 1 (new outer row added to each side)
	for entry in saved:
		var new_r: int = entry.row + 1
		if new_r < rows and entry.col < cols:
			cells[new_r][entry.col].place_unit(entry.unit_data, entry.texture)


func remove_rows() -> void:
	if rows <= MIN_ROWS:
		return
	var old_rows := rows
	var saved := _save_units()
	rows -= 2
	_build_grid()
	# Outer row of each side is removed (row 0 and old_rows-1)
	for entry in saved:
		var old_r: int = entry.row
		if old_r == 0 or old_r == old_rows - 1:
			continue
		var new_r := old_r - 1
		if new_r < rows and entry.col < cols:
			cells[new_r][entry.col].place_unit(entry.unit_data, entry.texture)


func add_cols() -> void:
	if cols >= MAX_COLS:
		return
	var saved := _save_units()
	cols += 1
	_build_grid()
	for entry in saved:
		if entry.row < rows and entry.col < cols:
			cells[entry.row][entry.col].place_unit(entry.unit_data, entry.texture)


func remove_cols() -> void:
	if cols <= MIN_COLS:
		return
	var saved := _save_units()
	cols -= 1
	_build_grid()
	# Last column (index == old cols-1 == new cols) is dropped
	for entry in saved:
		if entry.col < cols and entry.row < rows:
			cells[entry.row][entry.col].place_unit(entry.unit_data, entry.texture)
