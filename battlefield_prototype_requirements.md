# Combat Prototype — Requirements Document

## 1. Overview

A Godot 4.x prototype for a two-sided battlefield where a player can arrange unit sprites onto a resizable grid. The purpose is to validate the grid layout, unit placement flow, and drag-and-drop interaction before any combat logic is implemented.

---

## 2. Technology

- **Engine:** Godot 4.x (latest stable)
- **Language:** GDScript
- **Project type:** 2D

---

## 3. Screen Layout

The screen is divided into two vertical regions:

```
┌─────────────────────────────────────┐
│                                     │
│           BATTLEFIELD GRID          │  ~65% of screen height
│                                     │
├─────────────────────────────────────┤
│          CONTROL BUTTONS            │  ~10% of screen height
├─────────────────────────────────────┤
│                                     │
│             UNIT TRAY               │  ~25% of screen height
│                                     │
└─────────────────────────────────────┘
```

All three regions should be horizontally centered on screen. The layout should work at a fixed resolution of **1280×720**.

---

## 4. Battlefield Grid

### 4.1 Structure

- The grid is made up of rectangular **cell placeholders**.
- Each cell can hold **at most one unit** at a time.
- The grid is divided horizontally across the middle into two equal halves:
  - **Top half** — Side A (e.g., enemy army)
  - **Bottom half** — Side B (e.g., player army)
- The two halves should be visually distinct (e.g., a different background tint or a visible dividing line between them).
- The row count must always be even so that each side has an equal number of rows. The resize controls enforce this (rows increment/decrement in steps of 2).

### 4.2 Default Dimensions

| Parameter | Default Value |
|-----------|--------------|
| Rows      | 6 (3 per side) |
| Columns   | 6            |

### 4.3 Adjustable Dimensions

- Rows and columns are adjustable at runtime via the control buttons (see Section 5).
- **Minimum:** 2 rows (1 per side), 1 column.
- **Maximum:** 8 rows (4 per side), 12 columns.
- Row count must always be even to preserve the two-side split. The resize controls should enforce this (i.e., rows increment/decrement in steps of 2).
- Column count has no parity restriction and increments/decrements by 1.
- The grid should reflow and re-center visually immediately when dimensions change.

### 4.4 Cell Appearance

- Each cell is rendered as a visible rectangular placeholder (e.g., a Panel or a NinePatchRect with a border).
- Empty cells should be visually distinct from occupied cells (e.g., a highlight or tint change when a unit is present).
- Cells should provide visual feedback during drag-over (e.g., a highlight color when a dragged unit hovers over a valid empty cell).

### 4.5 Grid Sizing

- Cell size should be fixed (e.g., 64×64 px).
- The overall grid width/height is therefore `columns × cell_width` and `rows × cell_height`.
- The grid should be centered horizontally within the battlefield region.

---

## 5. Control Buttons

A row of buttons displayed between the battlefield and the unit tray. Each button performs an immediate resize of the grid:

| Button Label | Action                              |
|--------------|-------------------------------------|
| `+ Rows`     | Add two rows (one per side)         |
| `− Rows`     | Remove two rows (one per side)      |
| `+ Column`   | Add one column (up to maximum)      |
| `− Column`   | Remove one column (down to minimum) |

- Buttons that would exceed the min/max bounds should be **disabled** (greyed out) when the limit is reached.
- When a row or column is removed, any units occupying cells in that row/column are **destroyed** (removed from the battlefield and do NOT return to the tray).

---

## 6. Unit Tray

### 6.1 Purpose

The unit tray holds the available pool of unit sprites.

### 6.2 Layout

- Displayed as a horizontal row of unit slots at the bottom of the screen.
- Each slot displays one unit sprite.
- Slots should be spaced evenly and centered horizontally.

### 6.3 Pool Behavior

- The tray is a **unit type pool**: each slot represents a unit type, not a unique instance.
- The tray image is permanent — it is never removed or greyed out, regardless of how many units of that type are on the battlefield.
- Dragging from a tray slot always creates a new instance of that unit type; the slot itself is unaffected.
- There is no cap on how many units of the same type can be placed on the battlefield simultaneously.
- When a unit is dragged off the battlefield and released over an invalid area, it is simply destroyed (it does not need to return to the tray, since the type is always available there).

### 6.4 Sprites

Unit type definitions and their visual data are driven by two JSON files:

- **`assets/data/common.json`** — defines all unit types. Each entry contains an `id`, a `name`, and gameplay attributes. The tray should populate one slot per entry in this file, in the order they appear.
- **`assets/data/assets.json`** — maps each unit type name to its visual location within a sprite sheet. Each entry contains:
  - `name` — matches the unit type name in `common.json`
  - `image` — filename of the sprite sheet (located in `assets/sprites/units/`)
  - `x`, `y` — pixel offset of the sprite within the sheet
  - `width`, `height` — dimensions of the sprite (32×32 px in all current cases)

To display a unit type, the implementation should:
1. Look up the unit's `name` in `assets/data/assets.json` to find the sprite sheet and region.
2. Load the corresponding image from `assets/sprites/units/`.
3. Extract the sub-region defined by `x`, `y`, `width`, and `height` (e.g., using an `AtlasTexture` in Godot).

No assumptions should be made about the number of unit types; the tray should populate dynamically based on the entries present in `common.json`.

---

## 7. Drag-and-Drop Interaction

### 7.1 Dragging from the Tray

1. The player clicks and holds a unit sprite in the tray.
2. The sprite follows the mouse cursor while the button is held.
3. On release:
   - **Over an empty cell:** the unit is placed in that cell.
   - **Over an occupied cell:** the existing unit in that cell is destroyed and replaced by the dragged unit.
   - **Over an invalid area (outside the grid):** the dragged instance is destroyed with no effect on the tray.

### 7.2 Dragging from the Battlefield

1. The player clicks and holds a unit already placed on a cell.
2. The sprite follows the cursor while the button is held.
3. On release:
   - **Over a different empty cell:** the unit moves to the new cell.
   - **Over a different occupied cell:** the unit in that cell is destroyed and replaced by the dragged unit. The cell the drag originated from becomes empty.
   - **Over the unit's own cell:** the unit snaps back with no change.
   - **Over the unit tray or anywhere outside the grid:** the unit is destroyed (removed from play). Since the unit type always remains available in the tray, the player can drag a new instance if needed.

### 7.3 Visual Feedback During Drag

- The dragged sprite should render on top of all other elements (highest z-index).
- Both empty and occupied cells should highlight when a dragged unit hovers over them, as both are valid drop targets.
- Areas outside the grid should give no highlight or a distinct "invalid" visual cue.

---

## 8. File & Scene Structure (Recommended)

```
res://
├── scenes/
│   ├── main.tscn                  # Root scene, assembles all regions
│   ├── battlefield_grid.tscn      # Grid node, manages cells
│   ├── cell.tscn                  # Individual cell placeholder
│   ├── unit_tray.tscn             # Tray node, manages unit slots
│   └── unit.tscn                  # Draggable unit node
├── scripts/
│   ├── battlefield_grid.gd
│   ├── cell.gd
│   ├── unit_tray.gd
│   └── unit.gd
├── assets/
│   ├── sprites/
│   │   ├── units/                 # Unit sprite sheets (dg_*.png)
│   │   └── ui/                    # UI images (arrows, coin, favor, etc.)
│   └── data/
│       ├── common.json            # Unit type definitions (id, name, attributes)
│       └── assets.json            # Sprite sheet mapping (name → image, x, y, w, h)
└── icon.svg                       # Godot project icon
```

---

## 9. Out of Scope for This Prototype

The following are explicitly **not** required at this stage:

- Combat resolution or any game logic
- Turn management
- AI or computer-controlled side
- Animations (beyond snapping/returning)
- Sound
- Saving or loading state
- Victory/defeat conditions
- Unit statistics or attributes

---

## 10. Acceptance Criteria

- [ ] Grid renders with correct default dimensions (6 rows × 6 columns, 3 rows per side) on launch.
- [ ] Top and bottom halves of the grid are visually distinguishable.
- [ ] All four resize buttons function correctly and respect min/max limits.
- [ ] Disabled buttons are visually greyed out at bounds.
- [ ] Units removed by a resize operation disappear and do not return to the tray.
- [ ] Unit types are loaded dynamically from `assets/data/common.json`; the tray populates one slot per entry in the order they appear.
- [ ] Each unit's sprite is resolved via `assets/data/assets.json` — correct sprite sheet loaded from `assets/sprites/units/` and correct sub-region (`x`, `y`, `width`, `height`) extracted.
- [ ] Tray slots always display their unit type sprite regardless of how many instances are on the battlefield.
- [ ] Dragging from a tray slot creates a new unit instance; the tray slot is visually unchanged.
- [ ] Multiple units of the same type can coexist on the battlefield simultaneously.
- [ ] Dragging a unit from the tray to an empty cell places it on the grid.
- [ ] Dragging a unit from the tray to an occupied cell destroys the existing occupant and places the dragged unit in that cell.
- [ ] Dragging a unit from the tray to an area outside the grid destroys the dragged instance with no effect on the tray.
- [ ] Dragging a placed unit to another empty cell moves it.
- [ ] Dragging a placed unit to another occupied cell destroys the occupant, places the dragged unit there, and leaves the origin cell empty.
- [ ] Dragging a placed unit back to its own cell returns it with no change.
- [ ] Dragging a placed unit outside the grid destroys it.
- [ ] All cells (empty and occupied) highlight on hover during a drag.
- [ ] Cells highlight on hover during a valid drag.
- [ ] Dragged sprite renders above all other elements.
