extends RefCounted
class_name CombatResolver


static func roll_d6() -> int:
	return randi_range(1, 6)


static func roll_2d6() -> Dictionary:
	var pos := roll_d6()
	var neg := roll_d6()
	return {"pos": pos, "neg": neg, "net": pos - neg}


static func roll_damage(formula: String) -> int:
	formula = formula.strip_edges().to_lower()
	var re := RegEx.new()
	re.compile("^(\\d*)d(\\d+)([+-]\\d+)?$")
	var m := re.search(formula)
	if not m:
		return 0
	var n := int(m.get_string(1)) if m.get_string(1) != "" else 1
	var die := int(m.get_string(2))
	var mod := int(m.get_string(3)) if m.get_string(3) != "" else 0
	var total := 0
	for _i in range(n):
		total += randi_range(1, die)
	return total + mod


static func quality_mods(qualities: Array) -> Dictionary:
	var dm := 1.0
	var sm := 1.0
	var am := 1.0
	for q in qualities:
		match q:
			1:  # Magic
				dm *= 0.5
				sm *= 0.5
			2:  # Gunpowder — defense ignored, shield zeroed, armor halved
				dm = 0.0
				sm = 0.0
				am *= 0.5
			3:  # Ranged — defense ignored, shield doubled
				dm = 0.0
				sm *= 2.0
			4:  # Skirmish — defense halved, shield ×1.5
				dm *= 0.5
				sm *= 1.5
			6:  # Melee — full values
				pass
			7:  # AP — armor halved
				am *= 0.5
			8:  # Fire — armor zeroed
				am = 0.0
			9:  # Lightning — armor and shield halved
				am *= 0.5
				sm *= 0.5
	return {"def": dm, "shield": sm, "armor": am}


# Returns an array of log line strings. Mutates GameState.units (combatants arrays).
static func resolve_phase(gs: GameStateClass, p: int) -> Array:
	var log_lines: Array = []
	var active: Array = gs.get_active_units_for_phase(p)

	# Build flat roll list
	var roll_list: Array = []
	for attacker in active:
		var target_id = attacker.get("assigned_target_id")
		if target_id == null:
			continue
		var ut: Dictionary = gs.get_unit_type(attacker["type_id"])
		for atk in ut.get("attacks", []):
			if gs.get_attack_phase(atk.get("qualities", [])) != p:
				continue
			var qty: int = atk.get("quantity", 1)
			var n: int = qty * attacker["combatants"].size()
			for _i in range(n):
				roll_list.append({
					"attacker_id": attacker["id"],
					"target_id": target_id,
					"attack": atk
				})

	# Resolve each roll
	for entry in roll_list:
		var attacker: Dictionary = gs.get_unit(entry["attacker_id"])
		var target: Dictionary = gs.get_unit(entry["target_id"])
		if target.is_empty() or target["combatants"].is_empty():
			continue  # target already wiped

		var atk: Dictionary = entry["attack"]
		var qualities: Array = atk.get("qualities", [])
		var skill: int = atk.get("skill", 0)
		var support: int = attacker.get("support_bonus", 0) if p == 5 else 0

		var atk_roll: Dictionary = roll_2d6()
		var net_atk: int = atk_roll["net"]
		var atk_score: int = skill + net_atk + support
		var is_crit: bool = net_atk >= 4

		var def_pos := 0
		var def_neg := 0
		var def_score := 0
		var hit := is_crit

		if not is_crit:
			var def_roll: Dictionary = roll_2d6()
			def_pos = def_roll["pos"]
			def_neg = def_roll["neg"]
			var mods: Dictionary = quality_mods(qualities)
			var tut: Dictionary = gs.get_unit_type(target["type_id"])
			var eff_def: int = floori(float(tut.get("defense", 0)) * float(mods["def"]))
			var eff_shd: int = floori(float(tut.get("shield", 0)) * float(mods["shield"]))
			def_score = eff_def + eff_shd + int(def_roll["net"])
			hit = atk_score > def_score

		var aut: Dictionary = gs.get_unit_type(attacker["type_id"])
		var tut2: Dictionary = gs.get_unit_type(target["type_id"])
		var atk_name: String = aut.get("name", "?")
		var tgt_name: String = tut2.get("name", "?")

		var line := "%s → %s | atk [+%d/−%d] = %d" % [
			atk_name, tgt_name,
			atk_roll["pos"], atk_roll["neg"], atk_score
		]
		if is_crit:
			line += " CRIT"
		else:
			line += " | def [+%d/−%d] = %d" % [def_pos, def_neg, def_score]

		if not hit:
			line += " → miss"
			log_lines.append(line)
			continue

		# Damage
		var dmg_formula: String = atk.get("damage", "1")
		var rolled := roll_damage(dmg_formula)
		if is_crit:
			rolled += roll_damage(dmg_formula)

		var mods2: Dictionary = quality_mods(qualities)
		var armor_mult: float = 0.0 if is_crit else float(mods2["armor"])
		var eff_armor: int = int(maxf(0.0, floor(float(tut2.get("armor", 0)) * armor_mult)))
		var raw_dmg: int = max(0, rolled - eff_armor)

		line += " → hit, dmg %d" % rolled
		if eff_armor > 0:
			line += "−%d(armor)" % eff_armor
		line += " = %d" % raw_dmg

		# Apply all damage to one combatant
		var kills := 0
		if not target["combatants"].is_empty():
			var idx: int = randi() % target["combatants"].size()
			target["combatants"][idx] -= raw_dmg
			if target["combatants"][idx] <= 0:
				target["combatants"].remove_at(idx)
				kills = 1

		if kills > 0:
			line += " [1 killed]"

		log_lines.append(line)

	return log_lines
