# Combat Prototype — Technical Specification

*Derived from combat_mechanics.md and common.json*

---

## 1. Purpose and Scope

The prototype is built in **Godot 4.6**. All variables and field names use **snake_case**. It lets a player configure a battlefield, place units for both sides, and simulate combat one phase at a time. Each click of the **Fight** button advances one phase. The prototype covers Phase 1 (Start), Phases 3–5 (Ranged, Skirmish, Melee), and Phase 8 (Movement). Phases 2 (Magic) and Phase 6 (Divine) are out of scope.

---

## 2. Application State Machine

The application moves through two top-level modes:

| Mode | Description |
| ---- | ----------- |
| **Setup** | Player configures the battlefield and places units. Ends when the player clicks **Fight** for the first time. |
| **Combat** | The Fight button advances one phase at a time until the battle ends. |

---

## 3. Data Model

### 3.1 Quality IDs (from common.json)

| ID | Quality | Phase | Defense modifier | Shield modifier | Armor modifier |
| -- | ------- | ----- | ---------------- | --------------- | -------------- |
| 1  | Magic | Magic | ×0.5 | ×0.5 | — |
| 2  | Gunpowder | Ranged | ignored | ×0 | ×0.5 |
| 3  | Ranged | Ranged | ignored | ×2 | — |
| 4  | Skirmish | Skirmish | ×0.5 | ×1.5 | — |
| 6  | Melee | Melee | ×1 | ×1 | — |
| 7  | Armor Piercing | — | — | — | ×0.5 |
| 8  | Fire | — | — | — | ×0 |
| 9  | Lightning | — | — | — | ×0.5 (also shield ×0.5) |

The phase a given attack fires in is determined by the first quality in its `qualities` array that maps to a phase (IDs 1–6). Modifier qualities (7–9) stack on top and do not affect phase assignment.

### 3.2 UnitType

Loaded from `common.json`.

| Field | Type | Notes |
| ----- | ---- | ----- |
| `id` | int | |
| `name` | string | |
| `health` | int | Max HP per combatant |
| `defense` | int | Base defense skill |
| `armor` | int | Flat damage reduction; absent = 0 |
| `shield` | int | Base shield rating; absent = 0 |
| `attacks` | Attack[] | May be absent (spellcaster-only units) |
| `spells` | int[] | Spell IDs; out of scope for prototype |
| `spell_likes` | int[] | Spell-like ability IDs; out of scope |
| `hero` | bool | Absent = false |
| `holy` | bool | Absent = false |
| `cost` | int | Not used in prototype |
| `info` | string | Display only |

### 3.3 Attack

| Field | Type | Default | Notes |
| ----- | ---- | ------- | ----- |
| `skill` | int | required | Added to the attack roll |
| `damage` | string | required | Dice notation, e.g. `"2d6+1"` |
| `quantity` | int | 1 | Attacks per combatant per phase |
| `qualities` | int[] | required | At least one phase-determining quality |
| `max_range` | int | 1 | Ranged attacks only: furthest row reachable |
| `support_bonus` | int | 0 | Skirmish attacks only: flat attack bonus granted to the friendly melee unit directly in front when the skirmisher is in Row 2 |

### 3.4 BattlefieldConfig

Chosen by the player before combat begins. Locked once Fight is first clicked.

| Field     | Type | Constraint |
| --------- | ---- | ---------- |
| `rows`    | int  | 2–8        |
| `columns` | int  | ≥ 1        |

### 3.5 PlacedUnit

One entry per unit on the grid or in reserve.

| Field                | Type        | Notes                                                                                |
| -------------------- | ----------- | ------------------------------------------------------------------------------------ |
| `id`                 | int         | Unique instance ID                                                                   |
| `type_id`            | int         | References UnitType                                                                  |
| `side`               | 0 \| 1      | 0 = left/attacker, 1 = right/defender                                                |
| `combatants`         | int[]       | Array of current HP values, one per combatant. Length = number of combatants placed. |
| `row`                | int \| null | 1-indexed; null = reserve                                                            |
| `column`             | int \| null | 1-indexed; null = reserve                                                            |
| `assigned_target_id` | int \| null | Set during target-selection step; cleared after each phase resolves                  |
| `support_bonus`      | int         | Accumulated support bonus for this turn; reset each turn                             |

### 3.6 GameState

| Field | Type | Notes |
| ----- | ---- | ----- |
| `config` | BattlefieldConfig | |
| `units` | PlacedUnit[] | All units, both sides, grid and reserve |
| `phase` | int | Current phase: 1, 3, 4, 5, 7, or 8 |
| `turn` | int | Starts at 1 |
| `sub_step` | "targeting" \| "resolving" \| "movement" | Within-phase step |
| `log` | LogEntry[] | Human-readable event log |

---

## 4. Setup Mode

### 4.1 Battlefield Configuration Panel

Shown before any units are placed. Contains:

- **Rows** slider or number input: 2 to 8, the default is 4
- **Columns** input: positive integer

The grid preview updates live as the player adjusts these values. The two sides of the grid are mirror-images of each other separated by a centre divider.

### 4.2 Unit Roster

A scrollable panel listing all unit types from `common.json`. Each entry shows name, health, defense, armor, shield, attack summary, and info text. Units with no `attacks` array (spellcaster-only heroes) may still be placed but will not participate in any prototype phase.

### 4.3 Unit Placement

The player places units by dragging from the roster onto a grid cell for either side, or onto the reserve area below each side's grid. When dropping onto a grid cell:

- If the cell is empty, the unit is placed.
- If the cell is occupied, the current unit is replaced.

When a unit is placed, its combatant count is pre-filled from the `size` field on the unit type. The initial `combatants` array has `size` entries, all equal to `health`.

A unit can be removed from the grid by dragging it back to the roster panel.

### 4.4 Row Collapse

Row collapse is no longer a one-time pre-combat step. It is now executed during **Phase 1 (Start)** at the beginning of every turn, including Turn 1. See Section 5.1 and Section 6 for details.

---

## 5. Combat Mode

### 5.1 Phase Sequence

Each call to Fight advances through the following sequence. Phases with no participating units are skipped automatically.

| Phase | Name | Fight button behaviour |
| ----- | ---- | ---------------------- |
| 1 | Start | Automatic; row collapse applied |
| 3 | Ranged | Target selection → resolve |
| 4 | Skirmish | Target selection → resolve |
| 5 | Melee | Target selection → resolve |
| 7 | Cleanup | Automatic; dead units removed |
| 8 | Movement | Drag-and-drop; Fight confirms |

After Phase 8, turn increments and the sequence restarts at Phase 1.

On the first turn, Phase 8 is where the infantry advance and skirmisher withdrawal are expected to happen, but the player moves units freely with no rules enforced.

### 5.2 Fight Button Label

| Situation | Label | State |
| --------- | ----- | ----- |
| Setup mode, config not yet locked | **Start Battle** | Enabled |
| Start phase (auto) | **Next Phase** | Enabled |
| Targeting step, not all targets assigned | **Resolve Phase** | Disabled (greyed out) |
| Targeting step, all targets assigned | **Resolve Phase** | Enabled |
| Movement step | **Confirm Movement** | Enabled |
| Cleanup (auto) | **Next Phase** | Enabled |
| Battle over | **Restart** | Enabled |

---

## 6. Phase 1 — Start

Executed automatically (no player input required) at the beginning of every turn, including Turn 1. Fight button simply triggers it.

**Row collapse** is applied to each side independently:

1. Collect all rows (1 through `config.rows`) that contain at least one unit for this side, in ascending order.
2. Renumber them 1, 2, 3, … preserving relative order.
3. Update `row` on all affected PlacedUnits.

Units in reserve are not affected. Row collapse runs on every Phase 1 regardless of whether any rows were vacated that turn.

---

## 7. Target Selection Step

Applies to Phases 3, 4, and 5.

1. Determine the **active units** for this phase: all living units on the grid (not in reserve) whose `attacks` array contains at least one attack whose primary quality fires in this phase.
2. If there are no active units on either side, the phase is **skipped automatically** with no player input required.
3. Otherwise, the first active unit (in some deterministic order, e.g. top-to-bottom, left-to-right) is automatically highlighted as the **selected attacker**.
4. The player clicks any enemy unit to assign it as the target of the selected attacker. A visual indicator (arrow or highlight) shows the assignment.
5. After a target is assigned, the next active unit without a target is automatically highlighted. This continues until all active units have an assigned target.
6. The player may re-select any active attacker by clicking it, then click a different enemy unit to reassign its target.
7. There is no enforcement of range or column rules. Any active unit may target any unit on the opposing side.
8. The **Fight** button is disabled and greyed out until every active unit has an assigned target. Once all targets are assigned, the button becomes active. Clicking it resolves all attacks (see Section 8) and advances to the next phase.

---

## 8. Attack Resolution

Executed for all active units when the player clicks Resolve Phase.

### 8.1 Support Bonus Application

Applies during the Melee phase only. Before resolving any attacks:

For each living friendly melee unit in Row 1, find all skirmisher units on the same side that are in Row 2 and share the same column. Among those skirmishers, take the single highest `support_bonus` value across all of their skirmish attacks and assign it to that melee unit's `support_bonus` field. If no such skirmisher exists, the field remains 0.

Multiple skirmishers in the same column do not stack — only the highest bonus applies.

Reset all `support_bonus` fields to 0 at the start of each turn.

### 8.2 Generating Attack Rolls

For each active unit U with an assigned target T:

1. For each attack definition A in U's `attacks` whose primary quality fires in this phase:
   - Let `n = A.quantity × U.combatants.length`
   - Generate `n` attack rolls. Each roll:
     - Roll two independent d6: `pos` and `neg`
     - `net_roll = pos − neg`
     - `attack_score = A.skill + net_roll + U.support_bonus` (support bonus only applies in Melee phase)
     - `is_critical = (net_roll >= 4)`

2. Collect all rolls across all active units into a flat list for this phase.

3. Resolve each roll in list order (no sorting).

### 8.3 Resolving a Single Roll

Given attacker unit U, target unit T, attack definition A, attack_score, is_critical:

1. **Defense roll** (unless is_critical):
   - Roll two d6: `pos` and `neg`; `net_roll = pos − neg`
   - Compute effective defense and shield for T against A:
     - Apply quality modifiers from A's `qualities` to T's `defense` and `shield` values (see quality table in Section 3.1; all modifiers from qualities in the array are applied)
     - `defense_score = effective_defense + effective_shield + net_roll`
   - **Hit** if `attack_score > defense_score`

2. **Critical hit** always hits and bypasses all armor.

3. **Damage** (on hit):
   - Parse A's `damage` dice formula (e.g. `"2d6+1"`) and roll it
   - If critical: roll the damage formula twice and sum both results
   - Effective armor:
     - Start with T's `armor`
     - Apply quality modifiers (AP halves, Fire zeroes, critical zeroes, Lightning halves)
     - Floor at 0
   - `raw_damage = max(0, rolled_damage − effective_armor)`

4. **Damage application**:
   - Apply each point of `raw_damage` independently: pick a random index into T's `combatants` array (uniform), reduce that combatant's HP by 1. If it reaches 0, remove it from the array immediately.
   - If T's `combatants` array becomes empty, the unit is destroyed.

### 8.4 Partial Phases

When resolving a roll, check whether T's `combatants` array is already empty (destroyed by an earlier roll in the same resolution pass). If so, the roll is skipped.

---

## 9. Phase 7 — Cleanup

Executed automatically (no player input required). Fight button simply triggers it.

1. Remove all units whose `combatants` array is empty.
2. Log any units destroyed this turn.
3. Check victory conditions (Section 11).

---

## 10. Phase 8 — Movement

The player may drag any unit on the grid to any other cell on the same side, or to/from reserve.

**Swap rule:** If the destination cell is occupied by a friendly unit, the two units swap positions.

**Cross-side movement is not permitted.**

Units in reserve may be dragged onto empty grid cells. Units on the grid may be dragged to reserve.

The player clicks **Confirm Movement** when done. No moves are required; the player may skip by clicking the button immediately.

---

## 11. Victory Conditions

After every phase resolves (including Cleanup), check:

- If all living units on **Side 0** have been destroyed → Side 1 wins.
- If all living units on **Side 1** have been destroyed → Side 0 wins.
- Units in reserve count as living.

On victory, display a result banner and replace the Fight button with **Restart**.

---

## 12. UI Layout

```
┌─────────────────────────────────────────────────────────┐
│  Phase indicator   Turn counter   Phase log (scrollable) │
├─────────────────────────────────────────────────────────┤
│             Side 1 reserve                               │
├─────────────────────────────────────────────────────────┤
│             Side 1 grid  (rows × cols cells)             │
├─────────────────────────────────────────────────────────┤
│             Side 0 grid  (rows × cols cells)             │
├─────────────────────────────────────────────────────────┤
│             Side 0 reserve                               │
├─────────────────────────────────────────────────────────┤
│   Unit roster (all types from common.json)               │
├─────────────────────────────────────────────────────────┤
│                  [ Fight ]  button                       │
└─────────────────────────────────────────────────────────┘
```

- Clicking a grid cell containing a unit shows a **unit detail card**: name, combatant count, HP distribution, attack summary.
- During the targeting step, clicking an active attacker unit highlights it; clicking an ene