# Combat Mechanics

*Technical Design Reference*

# 1. Overview

Combat takes place between two sides — an attacker and a defender — in a specific province. Each side is composed of one or more units, where a unit is a fixed-size group of combatants of the same type sharing a common pool of wounds. Combat is turn-based and resolves through a fixed sequence of phases. Both sides act within every phase; there is no "attacker goes first" rule. Combat ends when one side is completely destroyed, or when the attacker chooses to retreat.

# 2. Participants

## 2.1 Units

A unit represents a fixed-size group of combatants of the same type. Each unit tracks the health of its individual combatants using a hit point distribution — an array recording how many combatants sit at each possible hit point level. For example, a unit of ten soldiers with 3 hit points each starts with ten combatants at full health. As damage accumulates, combatants slide down the distribution, and those that reach zero are removed.

Each attacking unit is associated with a retreat province — the province where surviving attackers return if the battle ends.

## 2.2 Unit Types

A unit type is the template that defines the properties shared by all combatants of that type. Every unit on the battlefield is an instance of a unit type. Unit types are defined in data and are not modified at runtime, except when a spell temporarily overrides a stat on an in-battle copy (as Mirror Image does when it clones the largest unit).

| **Parameter**            | **Description**                                                                                                                                                                                                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Name**                 | Display name identifying this unit type in the UI and game data.                                                                                                                                                                                                          |
| **Size**                 | Fixed number of combatants in every unit of this type. All units of the same type always have the same size; size does not change during combat except through casualties.                                                                                                |
| **Hit Points**           | Maximum hit points of each combatant. Also sets the die size used in wound checks at the end of combat (a combatant with 4 HP rolls a d4).                                                                                                                                |
| **Defense**              | Base skill added to the defense roll when the unit is targeted. Full value applies against melee attacks; halved against skirmish and magic attacks; ignored entirely against ranged attacks.                                                                             |
| **Shield**               | Base shield rating added to the defense roll. Effective value scales with the incoming attack type: doubled against ranged, +50 % against skirmish, halved against magic or lightning, zeroed by gunpowder or illusory attacks. The Magic Shield spell adds a further +2. |
| **Armor**                | Flat damage reduction applied after a hit lands. Halved by armor-piercing, gunpowder, and lightning attacks; ignored entirely by fire attacks and critical hits. The Stone Skin spell adds a further +2.                                                                  |
| **Training Cost**        | Resource cost to recruit one combatant of this type. Not applicable to heroes.                                                                                                                                                                                            |
| **Attacks**              | One or more attacks the unit can make. Each attack defines a skill value, a damage formula (dice notation), a quantity (attacks per combatant per phase), a max range (for Ranged attacks: the furthest row that can be targeted, expressed as a row number; defaults to 1, meaning the front row only), an optional support bonus (for Skirmish attacks in Row 2), and a set of qualities that determine the phase and special interaction rules. See Section 6 for full details.  |
| **Spells**               | Spells this unit type can cast during combat. Each spell fires during the appropriate sub-phase of the Magic or Divine phase. See Section 7 for full details.                                                                                                             |
| **Spell-like Abilities** | Passive self-targeted effects that activate automatically at the Start phase of each turn. Unlike spells, they require no casting action and always apply to the unit itself.                                                                                             |
| **Hero**                 | Boolean flag. Hero units cannot be recruited through normal training. The AI also excludes hero unit types from counter-unit analysis when evaluating army composition.                                                                                                   |
| **Holy**                 | Boolean flag. Holy units are immune to the Confusion spell and cannot be targeted by it.                                                                                                                                                                                  |
| **Flavor Text**          | Optional descriptive text displayed in the UI. Has no effect on combat resolution.                                                                                                                                                                                        |

# 3. Battlefield and Unit Placement

## 3.1 The Battlefield Grid

Combat takes place on a rectangular grid divided horizontally into two equal halves — one per side. Each cell holds at most one unit. The grid has four rows per side, each representing a distinct tactical depth:

| Row | Role | Notes |
| --- | ---- | ----- |
| 1 — Front | Melee contact line | The only row reachable by melee attacks. Skirmishers deploy here at the start of combat. Infantry advances here at the end of the first round (Phase 8). If no skirmishers are present, may be occupied by infantry or other units at deployment. |
| 2 — Second | Infantry / Skirmish support line | Infantry deploys here at the start of combat and advances to Row 1 after the first round. Skirmishers fall back to this row after their opening round and provide support to the front line from this position. |
| 3 — Third | Ranged line | Ranged units fire from here. |
| 4 — Rear | Support line | Spellcasters and other support units. |

Grid width — the number of columns — is determined by the terrain type of the province where combat occurs, following Field of Glory: Empires frontage parameters:

| Terrain | Columns |
| ------- | ------- |
| Plains  | 10      |
| Hills   | 6       |
| Steppes | 8       |
| Desert  | 8       |

## 3.2 Reserves

Units that exceed the grid's capacity, or that are deliberately held back, are kept in reserve. The reserve pool is unlimited. Reserve units do not participate in attack resolution and cannot be targeted.

## 3.3 Initial Placement

At the start of combat, units are placed on the grid automatically based on their type: skirmisher units deploy to Row 1, melee infantry fills Row 2, ranged units fill Row 3, and spellcasters or support units fill Row 4. Units that cannot fit on the grid wait in reserve.

If an army lacks one or more of these unit types, the corresponding rows are left empty and then collapsed: all occupied rows shift forward so there are no gaps. For example, an army with no skirmishers starts with infantry in Row 1, ranged units in Row 2, and spellcasters in Row 3. An army with only infantry and spellcasters starts with infantry in Row 1 and spellcasters in Row 2. This collapse applies at the start of combat only; rows are not re-collapsed mid-battle when units are destroyed.

Heroes can override the automatic placement of units under their command. In manually controlled battles, the player may override the hero's placement decisions.

## 3.4 Entering and Leaving the Battlefield

During combat, units may move between the grid and reserve. The decision to bring a reserve unit onto an available cell, or to withdraw a unit from the grid into reserve, is made by the hero in auto-resolved combat, or by the player in a manually controlled battle. Hero personality influences this behavior — a Bold hero commits reserves freely; a Conservative hero holds them back.

Local defenders follow the same placement rules as all other units. They occupy cells on the grid and may enter or leave reserve by the same means.

## 3.5 Attack Range

Every attack has an associated range that determines which rows it can reach:

- **Melee attacks** can only target units in the opponent's front row.
- **Ranged attacks** can target units up to their max range rows deep. A max range of 1 (the default) limits targeting to Row 1; a max range of 2 also reaches Row 2; a max range of 3 also reaches Row 3; a max range of 4 reaches all rows.
- **Skirmish attacks** can only target units in the opponent's front row.
- **Magic and divine attacks** follow the range rules defined by the specific spell or ability.

## 3.6 First-Round Advance

At the end of the first round, two simultaneous positional shifts occur across both sides of the battle.

**Infantry advance.** Each melee infantry unit in Row 2 moves forward into Row 1, closing with the enemy. Row 1 is the melee contact line and the only row reachable by melee attacks; infantry that has not yet advanced cannot be targeted by melee and cannot make melee attacks. If Row 1 is full, infantry remains in Row 2 until a slot opens.

**Skirmisher withdrawal.** Each skirmisher unit in Row 1 moves back into Row 2, falling in behind the advancing infantry. If no slot is available in Row 2, the unit remains in Row 1 until a slot opens. If the infantry did not fill the full battlefield width at deployment, skirmishers may have also occupied the uncovered columns at the sides of the front line; those units withdraw to Row 2 by the same rule.

**Subsequent rounds (Row 2 — Skirmish support).** Once settled in Row 2, skirmisher units adopt a support role. They continue to make skirmish attacks, which still target only the opponent's Row 1. A skirmisher unit in Row 2 additionally grants a support bonus to each friendly unit in Row 1 that shares its column — representing harassment fire and flanking pressure that degrades the enemy's front-line cohesion. The magnitude of this bonus is defined by the support bonus value on the skirmish attack.

Units in Row 2 and deeper cannot be targeted by melee attacks while at least one unit remains in the opposing Row 1. Once Row 1 is cleared, deeper rows become exposed to melee.

## 3.7 Attack Targeting

Section 3.5 governs which rows an attack can reach. This section governs which column — and therefore which enemy unit — an attack is directed at.

**Melee and skirmish attacks** use column-aligned targeting. The attacker preferentially targets the enemy unit occupying the same column in the eligible row. If that column is unoccupied, the attacker may instead target an enemy unit in an adjacent column (a diagonal attack). If neither the same column nor either adjacent column contains a valid target, the attack is not generated for that combatant.

**Ranged and magic attacks** are not restricted by column. They may target any occupied enemy position within the attack's row range, regardless of which column the attacker occupies.

**Divine attacks and spells** follow the targeting rules defined by the specific spell or ability, as described in Section 7.

# 4. Turn Structure

Each combat turn follows seven phases in a strict order. Attacks are generated and resolved within the phase appropriate to their type. After Cleanup, spell effects end, the turn counter increments, and the cycle repeats.

| **Phase** | **Name** | **What Happens**                                                                 |
| --------- | -------- | -------------------------------------------------------------------------------- |
| 1         | Start    | Spell-like abilities activate. Summoned units will be removed at end of turn.    |
| 2         | Magic    | Spells are cast in order: unit creation first, then defensive, then offensive.   |
| 3         | Ranged   | Ranged attacks fire. Defense skill is ignored; shields double in effectiveness.  |
| 4         | Skirmish | Skirmish attacks fire. Defense skill is halved; shields gain a 50 % bonus.       |
| 5         | Melee    | Standard melee attacks fire with full defense and shield values.                 |
| 6         | Divine   | Restorative spells heal wounded combatants. Dead combatants are not resurrected. |
| 7         | Cleanup  | Spell effects expire. Summoned creatures are removed. Turn counter advances.     |

Phases with no attacks and no notable events are skipped automatically. Combat resolution is fully automated.

# 5. Attack Resolution

## 5.1 Rolling to Attack

When a unit makes an attack, two six-sided dice are rolled — a positive die and a negative die. The attack roll is the positive die minus the negative die, giving a result between −5 and +5. This roll is added to the attack's skill value to produce the total attack score.

A critical hit occurs when the net roll (positive minus negative) is 4 or higher — i.e. the positive die beats the negative die by at least 4 (e.g. positive=5, negative=1). A critical hit doubles weapon damage and completely ignores the target's armor.

## 5.2 Rolling to Defend

The defender independently rolls two six-sided dice in the same way. The net defense roll is added to the unit's base defense skill and shield value to produce the total defense score.

## 5.3 Determining a Hit

An attack lands if the total attack score exceeds the total defense score, or if the attack is a critical hit. If neither condition is met, no damage is dealt.

## 5.4 Calculating Damage

When an attack hits, weapon damage is rolled according to the attack's damage formula (expressed in standard dice notation, e.g. 1d6+2). The target's armor value is subtracted from the rolled damage. The result, if positive, is applied to a randomly selected combatant in the defending unit.

If the attack is a critical hit, the damage roll is made twice — a base roll plus a bonus roll equal to another full damage roll. Armor is ignored regardless of the attack's other properties.

## 5.5 Damage Application

Each point of damage is applied to a single randomly chosen combatant in the target unit. A combatant's current hit points decrease accordingly. If a combatant reaches zero hit points it is removed immediately. Multiple points of damage from one hit can wound or kill different combatants, since each point targets a random combatant in the unit independently.

# 6. Attack Qualities

Every attack carries one or more qualities that determine which phase it fires in and how it interacts with defensive stats. A unit type can have multiple attacks with different qualities — for example, a unit that fires a bow and also fights in melee would have a Ranged attack and a Melee attack, each firing in its own phase.

| **Quality**         | **Effect on Defense / Shield / Armor**                                                                                                                               |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ranged              | Fires in Ranged phase. Completely bypasses defense skill. Shields are twice as effective against it. The attack's max range determines how many rows deep it can reach (1 = Row 1 only by default; 2 = Rows 1–2; 3 = Rows 1–3; 4 = all rows).                          |
| Skirmish            | Fires in Skirmish phase. Halves defense skill. Shields are 50 % more effective. If the attacking unit occupies Row 2, the attack's support bonus is applied to each friendly front-row unit sharing the skirmisher's column.                                          |
| Melee               | Fires in Melee phase. Full defense and shield values apply.                                                                                                          |
| Divine              | Fires in Divine phase. Standard resolution.                                                                                                                          |
| Magic               | Halves both the target's defense skill and shield value.                                                                                                             |
| Armor Piercing (AP) | Halves the target's armor value.                                                                                                                                     |
| Gunpowder           | Halves armor. Completely ignores shields.                                                                                                                            |
| Fire                | Completely ignores armor.                                                                                                                                            |
| Lightning           | Halves both armor and shield value.                                                                                                                                  |
| Illusory            | Bypasses all shields and armor, including spell-enhanced values. Illusory units themselves have no shield or armor, and their combatants have only 1 hit point each. |

## 6.1 Multiple Attacks

A unit type may define multiple attacks, and each attack may specify a quantity greater than one. Each attack generates one roll result per combatant in the unit, per attack definition, per quantity value. Units affected by the Confusion spell generate no attack rolls at all for the duration of the confusion.

# 7. Spells

Spells are divided into four categories, each acting at a different point in the turn:

  - **Unit Creation spells** fire first in the Magic phase and bring new units onto the battlefield. Summoned units are removed at the end of the Cleanup phase.

  - **Defensive spells** fire second in the Magic phase and buff friendly units.

  - **Offensive spells** fire third in the Magic phase and debuff or damage enemy units.

  - **Restorative spells** fire in the Divine phase and heal wounded combatants.

Spell-like abilities — passive effects tied to a unit's innate nature — activate at the very start of the turn before any phase begins.

Spells generally target the largest eligible unit on the appropriate side. All spell effects expire at the end of the Cleanup phase, and summoned or illusory units are removed at that point.

| **Spell**          | **Type**      | **Effect**                                                                                                                                                                                                                      |
| ------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Magic Shield       | Defensive     | Adds +2 to the shield value of the largest friendly unit not already shielded. The bonus is negated by Illusory attacks.                                                                                                        |
| Stone Skin         | Defensive     | Adds +2 to the armor value of the largest friendly unit not already affected. The bonus is negated by Illusory attacks.                                                                                                         |
| Heal               | Restorative   | Restores all combatants in a unit to full hit points. Targets the unit with the highest accumulated wound points. Does not resurrect dead combatants.                                                                           |
| Confusion          | Offensive     | Prevents the target unit from making any attacks. Targets the largest enemy unit. Has no effect on Holy units.                                                                                                                  |
| Summon Chaos Spawn | Unit Creation | Randomly summons one chaos spawn creature into battle. The creature is removed at the end of the Cleanup phase.                                                                                                                 |
| Mirror Image       | Unit Creation | Creates an illusory duplicate of the largest friendly unit. The copy has the same number of combatants, but each has only 1 hit point, no shield, no armor, and its attacks carry the Illusory quality. Removed at end of turn. |

# 8. Wound Checks

When combat ends — whether through total defeat or retreat — every combatant that is wounded (below maximum hit points but not dead) must pass a survival check. This applies regardless of whether the unit is on the battlefield or in reserve at the time combat ends: a unit that was wounded during active fighting and later moved to reserve still participates. Units that spent the entire battle in reserve without taking any damage are at full health and skip the check entirely.

The check is a die roll against a difficulty target equal to the combatant's remaining hit points. The die used has as many sides as the combatant's maximum hit points. For example, a combatant with a maximum of 4 hit points currently sitting at 1 hit point rolls a d4 and needs a result of 1 or lower — a 25 % survival chance. The same combatant at 3 hit points needs a roll of 1, 2, or 3 — a 75 % survival chance.

Combatants that pass the check survive at full hit points; combatants that fail die of their wounds. Combatants already at full health skip the check entirely.

If a restorative (Heal) caster is present on a side, all wound checks on that side receive a +2 bonus to the target number, making survival meaningfully more likely.

# 9. End of Combat

## 9.1 Victory Conditions

Combat ends as soon as one side has no units remaining. This is checked before each new batch of attacks is generated. If the attacker is wiped out, pending defender attacks are cancelled. If the defender is wiped out, pending attacker attacks are cancelled.

## 9.2 Retreat

The attacker may choose to retreat at any point during the battle. When a retreat is declared, remaining attacking units are returned to their designated retreat province and the combat ends. Wound checks are not performed on retreat — only direct kills during combat count.

## 9.3 Post-Combat Sequence

After the last unit on one side falls, the following cleanup occurs in order:

  - **Pending attack queues are cleared.**

  - **All spell effects are ended; summoned units are removed.**

  - **Restorative spells are cast one final time on both sides.**

  - **Wound checks are performed for all surviving wounded combatants on both sides.**

  - **Units with no remaining combatants are removed from the roster.**

  - **The combat is marked as finished and the result is broadcast.**

# 10. AI and Combat Simulation

The system supports two modes of damage calculation. In normal play, dice are rolled honestly for each attack. In simulation mode — used by the AI when planning invasions — the expected damage is computed mathematically by iterating over all 1,296 combinations of two attacker dice and two defender dice and averaging the results. This lets the AI evaluate hypothetical battles without random variance affecting the outcome.

Computed expected-damage values are cached per attacker type, defender type, and combat phase, so repeated lookups during a single planning session are fast. The cache is bypassed if either side has active spell effects, since spells change the effective stats involved in the calculation.
