extends Node
class_name GameStateClass

const QUALITY_TO_PHASE: Dictionary = {2: 3, 3: 3, 4: 4, 6: 5}
const PHASE_NAMES: Dictionary = {1: "Start", 3: "Ranged", 4: "Skirmish", 5: "Melee", 7: "Cleanup", 8: "Movement"}

enum AppMode { SETUP = 0, COMBAT = 1 }

var app_mode: int = AppMode.SETUP
var config: Dictionary = {"rows": 4, "columns": 6}
var units: Array = []
var phase: int = 1
var turn: int = 1
var sub_step: String = "auto"   # "auto" | "targeting" | "movement"
var log_entries: Array = []
var winner: int = -1            # -1 = none, 0 = side 0 wins, 1 = side 1 wins
var next_unit_id: int = 1
var unit_types: Array = []

signal log_entry_added(text: String)


func _ready() -> void:
	_load_unit_types()


func _load_unit_types() -> void:
	var file := FileAccess.open("res://assets/data/common.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			unit_types = parsed.get("units", [])


func rows_per_side() -> int:
	return config["rows"] / 2


# ── Unit type queries ─────────────────────────────────────────────────────────

func get_unit_type(type_id: int) -> Dictionary:
	for ut in unit_types:
		if ut.get("id", -1) == type_id:
			return ut
	return {}


# ── PlacedUnit queries ────────────────────────────────────────────────────────

func get_unit(unit_id: int) -> Dictionary:
	for u in units:
		if u.get("id", -1) == unit_id:
			return u
	return {}


func get_units_in_reserve(side: int) -> Array:
	var result: Array = []
	for u in units:
		if u["side"] == side and u["row"] == null:
			result.append(u)
	return result


func get_unit_at_cell(side: int, game_row: int, col: int) -> Dictionary:
	for u in units:
		if u["side"] == side and u["row"] == game_row and u["column"] == col:
			return u
	return {}


# ── PlacedUnit mutations ──────────────────────────────────────────────────────

func create_placed_unit(type_id: int, side: int, row, col) -> Dictionary:
	var ut := get_unit_type(type_id)
	if ut.is_empty():
		return {}
	var size: int = ut.get("size", 1)
	var health: int = ut.get("health", 1)
	var combatants: Array = []
	combatants.resize(size)
	combatants.fill(health)
	var pu := {
		"id": next_unit_id,
		"type_id": type_id,
		"side": side,
		"combatants": combatants,
		"row": row,
		"column": col,
		"assigned_target_id": null,
		"support_bonus": 0
	}
	next_unit_id += 1
	units.append(pu)
	return pu


func remove_unit(unit_id: int) -> void:
	for i in range(units.size()):
		if units[i]["id"] == unit_id:
			units.remove_at(i)
			return


func move_unit(unit_id: int, row, col) -> void:
	var u := get_unit(unit_id)
	if not u.is_empty():
		u["row"] = row
		u["column"] = col


# ── Phase helpers ─────────────────────────────────────────────────────────────

func get_attack_phase(qualities: Array) -> int:
	for q in qualities:
		var qi: int = int(q)
		if QUALITY_TO_PHASE.has(qi):
			return int(QUALITY_TO_PHASE[qi])
	return -1


func get_active_units_for_phase(p: int) -> Array:
	var result: Array = []
	for u in units:
		if u["combatants"].is_empty() or u["row"] == null:
			continue
		var ut := get_unit_type(u["type_id"])
		if not ut.has("attacks"):
			continue
		for atk in ut["attacks"]:
			if get_attack_phase(atk.get("qualities", [])) == p:
				result.append(u)
				break
	return result


func all_targets_assigned() -> bool:
	for u in get_active_units_for_phase(phase):
		if u["assigned_target_id"] == null:
			return false
	return true


func clear_targets() -> void:
	for u in units:
		u["assigned_target_id"] = null


func reset_support_bonuses() -> void:
	for u in units:
		u["support_bonus"] = 0


func compute_support_bonuses() -> void:
	for side in [0, 1]:
		for col in range(1, config["columns"] + 1):
			var front := get_unit_at_cell(side, 1, col)
			if front.is_empty() or front["combatants"].is_empty():
				continue
			var best := 0
			var row2 := get_unit_at_cell(side, 2, col)
			if not row2.is_empty() and not row2["combatants"].is_empty():
				var ut := get_unit_type(row2["type_id"])
				for atk in ut.get("attacks", []):
					if get_attack_phase(atk.get("qualities", [])) == 4:
						best = max(best, atk.get("support_bonus", 0))
			front["support_bonus"] = best


func get_next_phase_after(p: int) -> int:
	match p:
		1:
			for np in [3, 4, 5]:
				if not get_active_units_for_phase(np).is_empty():
					return np
			return 7
		3:
			for np in [4, 5]:
				if not get_active_units_for_phase(np).is_empty():
					return np
			return 7
		4:
			if not get_active_units_for_phase(5).is_empty():
				return 5
			return 7
		5:
			return 7
		7:
			return 8
		8:
			return 1
	return 1


# ── Row collapse ──────────────────────────────────────────────────────────────

func apply_row_collapse(side: int) -> void:
	var occupied: Array = []
	for u in units:
		if u["side"] == side and u["row"] != null and not occupied.has(u["row"]):
			occupied.append(u["row"])
	occupied.sort()
	var row_map: Dictionary = {}
	for i in range(occupied.size()):
		row_map[occupied[i]] = i + 1
	for u in units:
		if u["side"] == side and u["row"] != null and row_map.has(u["row"]):
			u["row"] = row_map[u["row"]]


# ── Victory ───────────────────────────────────────────────────────────────────

func check_victory() -> int:
	var alive := [false, false]
	for u in units:
		if not u["combatants"].is_empty():
			alive[u["side"]] = true
	if not alive[0]:
		return 1
	if not alive[1]:
		return 0
	return -1


# ── Log ───────────────────────────────────────────────────────────────────────

func add_log(text: String) -> void:
	log_entries.append(text)
	print(text)
	emit_signal("log_entry_added", text)


# ── Reset ─────────────────────────────────────────────────────────────────────

func full_reset() -> void:
	app_mode = AppMode.SETUP
	config = {"rows": 4, "columns": 6}
	units = []
	phase = 1
	turn = 1
	sub_step = "auto"
	log_entries = []
	winner = -1
	next_unit_id = 1
