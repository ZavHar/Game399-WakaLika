## Goal
Migrate the current **React + TypeScript + Vite** game into **Godot** (recommended: **Godot 4.x**) while keeping gameplay parity and minimizing “rewrite risk” by moving systems in phases.

This plan assumes your current project has:
- A tile/grid-based Pac-Man-like core loop (movement, pellets, ghosts, collisions)
- A JSON-authored level layout file (maze editor writes `levelGrids.json`)
- Canvas/2D rendering and debug overlays (ghost path lines, etc.)
- Audio (Howler)

## Guiding principles
- **Port behavior, not code**: replicate mechanics via acceptance tests and reference runs.
- **Data-first migration**: keep level data format stable early so the game remains playable while systems move.
- **One “source of truth” per phase**: avoid running the same system in both engines at once except during short verification windows.
- **Keep debug visibility**: reimplement debug drawing early in Godot so you can validate AI/pathfinding and collisions.

## Phase 0 — Preflight and scope lock (0.5–1 day)
- **Decide Godot stack**
  - Rendering: `Node2D`/`CanvasItem` (2D), not 3D.
  - Language: **GDScript** (fast iteration) or **C#** (strong typing). Recommendation: **GDScript** unless you already prefer C#.
  - Target engine: **Godot 4.x** (you have **Godot 4.6.2** installed).
- **Freeze level format**
  - Keep `levelGrids.json` compatible at first. Only change it after the Godot port is stable.
- **Record baseline behaviors** (copy these values into the Godot port so “feel” matches)
  - **Speeds / stepping**
    - Pac speed: **5 tiles/sec** (`PAC_TILES_PER_SEC = 5`)
    - Ghost speed: **3 tiles/sec** (`GHOST_TILES_PER_SEC = 3`)
    - Pac substeps per frame: **6** (`PAC_SUBSTEPS_PER_FRAME = 6`)
    - Max tile steps per frame (Pac + ghosts safety): **8** (`MAX_TILE_STEPS_PER_FRAME = 8`)
  - **Collisions**
    - Pellet collect radius: **0.35 tiles** (`PELLET_COLLECT_RADIUS = 0.35`)
    - Pac-vs-ghost collision radius: **0.5 tiles** (`PAC_GHOST_COLLISION_RADIUS = 0.5`)
  - **Turning / input**
    - Turn-center epsilon: **0.14 tiles** (`TURN_CENTER_EPS = 0.14`)
    - Buffered-dir release clear: **100 ms** (`BUFFERED_DIR_RELEASE_CLEAR_MS = 100`)
  - **Gameplay rules to preserve**
    - Pac cannot enter: **Wall**, **Exit**, **GhostHouse**
    - Ghosts can enter: **GhostHouse**; **Exit** is “door-like” (allowed depending on from-tile rule)
    - Pinky target fallback when unreachable: **4→3→2→1→0 tiles ahead**, then Pac-goal, then random
  - **Timing**
    - Level timer: **600 seconds** (`LEVEL_DURATION = 600`)
    - Fear duration: **10,000 ms** (`FEAR_DURATION_MS = 10_000`)
    - Fear “flash” window: **2,000 ms** (`FEAR_FLASH_MS = 2_000`)

Deliverable:
- A short checklist of “must match” behaviors.
- A Godot project created with **strict GDScript typing** (see below).

### Phase 0 acceptance checklist (use this as your “parity contract”)
- **Movement feel**
  - Pac traverses exactly ~5 tiles in 1 second in open corridors.
  - Ghosts traverse exactly ~3 tiles in 1 second in open corridors.
- **Input buffering**
  - Buffered turns trigger when Pac is within `TURN_CENTER_EPS` of tile center.
  - Releasing a buffered (invalid) turn clears within ~100 ms.
- **AI correctness**
  - Pinky never “goes random” just because the ideal target is unreachable; it falls back toward Pac.
- **Collisions**
  - Pellet pickup radius and Pac-ghost collision radius match the TS build.

### Godot strict typing setting (required)
In the new Godot project’s `project.godot`, set:
- `debug/gdscript/warnings/untyped_declaration = 2` (**Error**)

This makes Godot emit an error if a variable/parameter/return type lacks a type annotation (unless it’s inferred with `:=`).

## Phase 1 — Create a Godot skeleton project (0.5–1 day)
Create a new Godot project alongside the current one (don’t delete the web version yet).

Scene layout (suggested):
- `Main.tscn`
  - `GameRoot` (`Node2D`)
    - `Board` (`Node2D`)
    - `Entities` (`Node2D`)
    - `Debug` (`Node2D`)
    - `UI` (`CanvasLayer`)

Godot project structure (suggested):
- `scenes/`
- `scripts/`
  - `data/` (types + constants)
  - `board/` (grid + tile queries)
  - `entities/` (pac, ghost)
  - `ai/` (pathfinding + targeting)
  - `rendering/` (tile atlas helpers)
- `assets/`
  - `tiles/` (wall atlas, pellet/exit sprites)
  - `audio/`

Deliverables:
- Game launches and shows an empty board region + UI shell.
- A fixed timestep loop wired (see Phase 3).

## Phase 2 — Import level data into Godot (1 day)
Goal: load `levelGrids.json` (or the Godot-copied equivalent) and build an in-memory grid.

Tasks:
- Copy `levelGrids.json` into Godot `res://assets/data/levelGrids.json`
- Implement a loader:
  - Parse JSON into a `Dictionary` of layouts (string → 2D int array)
  - Validate dimensions (36 rows, 28 cols total, or 14-half mirrored depending on your current rules)
- Implement tile queries equivalent to your TS engine:
  - `is_wall(x,y)`, `is_exit(x,y)`, `is_ghost_house(x,y)`
  - `is_pac_blocked(x,y)` and `is_ghost_step_blocked(from,to)`

Deliverables:
- A debug view that can draw the grid as solid-colored rectangles (temporary).
- A console print or on-screen text confirming layout names and dimensions.

## Phase 3 — Port core simulation loop (1–2 days)
Goal: replicate movement timing deterministically.

Recommended approach:
- Use `_physics_process(delta)` as the authoritative tick.
- Use a **fixed step** accumulator (e.g., 60 Hz) so the game is consistent regardless of FPS.

Tasks:
- Port constants into Godot:
  - `PAC_TILES_PER_SEC`, `GHOST_TILES_PER_SEC`, collision radii, buffered-turn thresholds, etc.
- Implement Pac movement:
  - Continuous position (float tiles)
  - Buffered input direction and “commit turn when centered” rule
  - Prevent entering walls/exit/ghost house
- Implement pellet collection rules and scoring.

Deliverables:
- Pac moves correctly around walls and eats pellets.
- Level completion detection (pellets cleared) matches baseline.

## Phase 4 — Port ghost movement and BFS pathfinding (2–3 days)
Goal: match ghost stepping and routing.

Tasks:
- Implement BFS shortest-path on the grid (4-neighbor movement)
  - Include “avoid immediate 180° on first step unless dead end” rule if you rely on it
- Implement ghost stepping:
  - Accumulator-based steps: \(acc += speed * delta\); while acc ≥ 1 → step
  - Respect `MAX_TILE_STEPS_PER_FRAME` equivalent to avoid spiral of death
- Implement ghost target selection:
  - Red: Pac goal tile
  - Pink: “ahead of Pac” target with progressive fallback when unreachable
  - Blue: vectoring off red + fallback to nearest walkable
  - Orange: scatter when near; otherwise chase

Deliverables:
- Ghosts navigate the maze (no random fallback unless truly unreachable).
- Debug overlay draws each ghost’s path (solid, transparent, behind tiles).

## Phase 5 — Rendering parity with sprites + wall autotiling (1–2 days)
Goal: match (or improve) the current wall atlas look without tile seams.

Tasks:
- Import tile atlas assets into Godot
  - Wall atlas (autotile atlas)
  - Pellet/exit sprites (optional)
- Use one of these Godot approaches:
  - **TileMap + TileSet** (recommended): configure an **atlas source** and **terrain/autotile** rules for seamless walls
  - Or manual draw: `MultiMeshInstance2D` or `CanvasItem.draw_texture_rect_region()` for each cell
- Ensure “no seams”:
  - Prefer TileMap (it handles pixel snapping well)
  - Use integer pixel alignment and enable pixel snap if needed

Deliverables:
- Walls connect seamlessly with 8-neighbor logic.
- Ghost-house tiles render invisible (if that’s your desired behavior).

## Phase 6 — Audio migration (0.5–1 day)
Goal: replace Howler usage with Godot audio.

Tasks:
- Map events to Godot `AudioStreamPlayer` nodes:
  - Pellet chomp, death, intro, etc.
- Add a small audio manager script:
  - preload streams
  - one-shots and looping tracks

Deliverables:
- All current sound cues present and timed correctly.

## Phase 7 — Replace the in-browser level editor (optional, 2–5 days)
You have options:
- **Option A (fastest)**: keep the existing React editor as a separate tool that outputs JSON, then import into Godot.
- **Option B (best integration)**: build a Godot in-editor tool:
  - Use `EditorPlugin` + a custom dock, or a runtime “Editor Mode” scene
  - Save JSON or Godot resources (`.tres`)

Deliverables:
- A stable pipeline for authoring and saving levels.

## Phase 8 — Cleanup and hardening (1–2 days)
- Remove web-only code/assets that are no longer needed (after Godot is stable)
- Add automated checks:
  - quick smoke test scene
  - simple “AI path exists” validation for each layout
- Performance pass (TileMap batching, pathfinding cache if necessary)

## Risk list (and how we mitigate)
- **Behavior drift** (ghost AI, turn buffering)
  - Mitigation: keep Phase 0 baseline notes + implement debug overlays early
- **Tile seams / scaling differences**
  - Mitigation: use TileMap/Tileset terrains; lock resolution and scaling rules
- **Editor pipeline disruption**
  - Mitigation: keep React editor as an external tool until late

## Definition of “done”
- Godot build plays end-to-end with:
  - Same map(s), pellets, scoring, timer
  - Ghost AI behavior parity
  - Audio parity
  - Stable level import pipeline

