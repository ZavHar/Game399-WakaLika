extends RefCounted
class_name GameModel

const FULL_W: int = 28
const H: int = 36

const DIR_UP: int = 0
const DIR_DOWN: int = 1
const DIR_LEFT: int = 2
const DIR_RIGHT: int = 3

const LEVEL_DURATION_S: float = 300.0
const PAC_TILES_PER_SEC: float = 5.0
## After this fraction of level time has elapsed, Pac reaches max ramp speed; then speed stays flat.
const PAC_SPEED_MAX_RAMP: float = 9.0
const GHOST_SPEED_MAX_RAMP: float = 10.0
const SPEED_RAMP_COMPLETE_FRACTION: float = 0.9
const PAC_SUBSTEPS_PER_FRAME: int = 6
const PELLET_SCORE: int = 10
const PELLET_COLLECT_RADIUS_TILES: float = 0.35
## Larger cornering window lets Pac commit turns earlier than center (classic cornering feel).
const TURN_CENTER_EPS_TILES: float = 0.34
const SNAP_IF_BEYOND_TILES: float = 1.0

const GHOST_TILES_PER_SEC: float = 3.0
const MAX_GHOST_TILE_STEPS_PER_FRAME: int = 8
const ORANGE_SCATTER_DISTANCE: int = 8

## Base fear length at full level timer; scales down linearly to `FEAR_DURATION_END_FRACTION` when time hits 0.
const FEAR_DURATION_MS: float = 10000.0
const FEAR_DURATION_END_FRACTION: float = 0.5
## Tile speed multiplier while power-pellet fear is active (non-incapacitated ghosts only).
const GHOST_FEAR_SPEED_MULT: float = 0.6
const GHOST_EATEN_SCORE: int = 200
const PAC_GHOST_COLLISION_RADIUS_TILES: float = 0.5
const FRUIT_SCORE: int = 200
const FRUIT_SIDE_FLASH_DURATION_MS: float = 250.0
const LEFT_FRUIT_SPAWN_LOCAL: Vector2i = Vector2i(9, 17)
const FRUIT_HUE_SHIFT_STEP: float = 0.05
const FRUIT_HUE_SHIFT_LERP_PER_SEC: float = 0.5
const VACUUM_RADIUS_TILES: float = 3.25
const GHOST_EATEN_COMBO_BASE: int = 200
const JUICE_POPUP_DURATION_MS: float = 800.0
const FRUIT_SWEEP_DURATION_MS: float = 380.0
## After a half has no pellets, wait this long before the fruit appears on the opposite side.
const FRUIT_SPAWN_DELAY_AFTER_SIDE_CLEAR_MS: float = 5000.0

const INCAP_PHASE_ROAM: String = "roam"
const INCAP_PHASE_RETURN: String = "return_to_house"
const INCAP_PHASE_WAITING: String = "waiting_in_house"
## After board swap etc.: ghost inside a wall tile paths to nearest non-wall, phasing through walls.
const INCAP_PHASE_UNSTICK: String = "unstick_wall"
const GHOST_RELEASE_SPACING_MS: float = 3000.0

# Rendering parity state (mirrors web GameState fields; not all gameplay is ported yet).
var fear_ms: float = 0.0
var fruit_active_left: bool = false
var fruit_active_right: bool = false
var left_side_clear_progress: float = 0.0 # 0..1
var right_side_clear_progress: float = 0.0 # 0..1
var left_side_fruit_flash_ms: float = 0.0
var right_side_fruit_flash_ms: float = 0.0
var left_side_fruit_sweep_ms: float = 0.0
var right_side_fruit_sweep_ms: float = 0.0
## Right half cleared → delay before `fruit_active_left`; left half cleared → delay before `fruit_active_right`.
var _fruit_spawn_delay_left_ms: float = 0.0
var _fruit_spawn_delay_right_ms: float = 0.0
var _fruit_spawn_left_episode: bool = false
var _fruit_spawn_right_episode: bool = false
var hue_shift_amount: float = 0.0
var hue_shift_target: float = 0.0
var vacuum_mode: bool = false

var pellets_left_left: int = 0
var pellets_left_right: int = 0

var board: BoardModel
var score: int = 0
var time_remaining_s: float = LEVEL_DURATION_S
## Updated each `step` from time ramp (used for Pac + ghost base `speed_tiles_per_sec`).
var _pac_speed_ramped: float = PAC_TILES_PER_SEC
var _ghost_speed_ramped: float = GHOST_TILES_PER_SEC
var is_game_over: bool = false
var lives: int = 3
var pac_waiting_for_input: bool = true
var _pac_death_triggered: bool = false

var pac_pos: Vector2 = Vector2(1.5, 1.5) # tile coords, continuous
var pac_dir: int = DIR_LEFT
var desired_dir: int = DIR_LEFT
## Bitmask `(1 << dir)` for `DIR_*` while keys are held; 0 = no direction input this frame.
var held_dirs_mask: int = 0
## Stabilize dual-key resolution at intersections (avoids flip-flopping each substep).
var _dual_input_latch_dir: int = -1
var _dual_input_latch_tile: Vector2i = Vector2i(-999, -999)
var buffered_dir: int = -1

var pellets: Array = [] # Array[Array[bool]]
var ghosts: Array = [] # Array[RefCounted] (GhostState)
var board_revision: int = 0
var sfx_pellet: bool = false
var sfx_power_pellet: bool = false
var sfx_fruit_left: bool = false
var sfx_fruit_right: bool = false
var sfx_ghost_eaten: bool = false
var sfx_pac_death: bool = false
var sfx_game_over: bool = false
var hitstop_ms: float = 0.0
var ghost_eat_chain: int = 0
var juice_popups: Array = [] # Array[Dictionary]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _half_layouts: Array = [] # Array[Array[Array[int]]]

func init_from_board(board_model: BoardModel) -> void:
	board = board_model
	_init_pellets()
	_init_ghosts()
	score = 0
	time_remaining_s = LEVEL_DURATION_S
	_pac_speed_ramped = PAC_TILES_PER_SEC
	_ghost_speed_ramped = GHOST_TILES_PER_SEC
	# Match TS PAC_SPAWN = { x: 13, y: 26 } and ensure spawn is never inside a blocked tile.
	var preferred_spawn: Vector2i = Vector2i(13, 26)
	var spawn_tile: Vector2i = board.nearest_pac_spawn_tile(preferred_spawn)
	pac_pos = Vector2(float(spawn_tile.x) + 0.5, float(spawn_tile.y) + 0.5)
	pac_dir = DIR_LEFT
	desired_dir = pac_dir
	held_dirs_mask = 0
	_dual_input_latch_dir = -1
	_dual_input_latch_tile = Vector2i(-999, -999)
	buffered_dir = -1
	fear_ms = 0.0
	is_game_over = false
	lives = 3
	pac_waiting_for_input = true
	_pac_death_triggered = false

	_recount_pellets_by_side()
	left_side_clear_progress = 1.0 if pellets_left_left == 0 else 0.0
	right_side_clear_progress = 1.0 if pellets_left_right == 0 else 0.0
	left_side_fruit_flash_ms = 0.0
	right_side_fruit_flash_ms = 0.0
	left_side_fruit_sweep_ms = 0.0
	right_side_fruit_sweep_ms = 0.0
	_fruit_spawn_delay_left_ms = 0.0
	_fruit_spawn_delay_right_ms = 0.0
	_fruit_spawn_left_episode = false
	_fruit_spawn_right_episode = false
	hue_shift_amount = 0.0
	hue_shift_target = 0.0
	vacuum_mode = false
	hitstop_ms = 0.0
	ghost_eat_chain = 0
	juice_popups = []
	_load_half_layout_pool()
	_sync_fruit_actives()

func _init_pellets() -> void:
	pellets = []
	for y: int in range(H):
		var row: Array = []
		row.resize(FULL_W)
		for x: int in range(FULL_W):
			var t: int = board.tile_at(x, y)
			row[x] = (t == Tile.Id.PELLET) or (t == Tile.Id.POWER_PELLET)
		pellets.append(row)

func _recount_pellets_by_side() -> void:
	var left_count: int = 0
	var right_count: int = 0
	for y: int in range(H):
		var row: Array = pellets[y] as Array
		for x: int in range(FULL_W):
			if not (row[x] as bool):
				continue
			if x < 14:
				left_count += 1
			else:
				right_count += 1
	pellets_left_left = left_count
	pellets_left_right = right_count

func set_desired_dir(next_dir: int) -> void:
	set_held_dirs_mask(1 << next_dir)

func set_held_dirs_mask(mask: int) -> void:
	var m: int = mask & 15
	if m != held_dirs_mask:
		_dual_input_latch_dir = -1
		_dual_input_latch_tile = Vector2i(-999, -999)
	held_dirs_mask = m
	var held: Array[int] = _dirs_from_held_mask(held_dirs_mask)
	if held.size() == 1:
		desired_dir = held[0]
	elif held.size() > 1:
		desired_dir = _pick_priority_dir_first(held)

func step(dt: float) -> void:
	_clear_sfx_flags()
	if is_game_over:
		return
	if _pac_death_triggered:
		return

	# timer
	time_remaining_s = max(0.0, time_remaining_s - dt)
	if time_remaining_s <= 0.0:
		time_remaining_s = 0.0
		if not is_game_over:
			is_game_over = true
			sfx_game_over = true
			_add_hitstop(95.0)
		return

	var fear_prev: float = fear_ms
	if fear_ms > 0.0:
		fear_ms = max(0.0, fear_ms - dt * 1000.0)
		if fear_prev > 0.0 and fear_ms <= 0.0:
			ghost_eat_chain = 0

	_decrement_incap_wait_ms(dt)
	_tick_ghost_release_timers(dt)
	_decrement_fruit_flash_ms(dt)
	_decrement_fruit_spawn_delays(dt)
	_update_hue_shift(dt)
	_tick_juice_popups(dt)

	_apply_time_ramp_speeds()
	_repair_ghosts_if_inside_wall()

	# Pac movement with substeps (matches TS structure)
	var sub_dt: float = dt / float(PAC_SUBSTEPS_PER_FRAME)
	for i: int in range(PAC_SUBSTEPS_PER_FRAME):
		_advance_pac(sub_dt)
		_collect_pellets()
	_handle_fruit_collection()

	_update_ghost_destinations()
	_step_ghosts(dt)

	_check_pac_ghost_collisions()

	_update_side_clear_progress(float(dt))

func _time_speed_ramp_u() -> float:
	var total: float = LEVEL_DURATION_S
	if total <= 0.0001:
		return 1.0
	var elapsed: float = total - time_remaining_s
	var denom: float = total * SPEED_RAMP_COMPLETE_FRACTION
	if denom <= 0.0001:
		return 1.0
	return clampf(elapsed / denom, 0.0, 1.0)


func _apply_time_ramp_speeds() -> void:
	var u: float = _time_speed_ramp_u()
	_pac_speed_ramped = lerpf(PAC_TILES_PER_SEC, PAC_SPEED_MAX_RAMP, u)
	_ghost_speed_ramped = lerpf(GHOST_TILES_PER_SEC, GHOST_SPEED_MAX_RAMP, u)
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		g.set("speed_tiles_per_sec", _ghost_speed_ramped)


func _clear_sfx_flags() -> void:
	sfx_pellet = false
	sfx_power_pellet = false
	sfx_fruit_left = false
	sfx_fruit_right = false
	sfx_ghost_eaten = false
	sfx_pac_death = false
	sfx_game_over = false
	hitstop_ms = 0.0

func _add_hitstop(ms: float) -> void:
	hitstop_ms = maxf(hitstop_ms, ms)

func _add_score_popup(tile: Vector2i, text: String, color: Color, scale: float = 1.0) -> void:
	var d: Dictionary = {
		"pos": Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5),
		"text": text,
		"color": color,
		"ms": JUICE_POPUP_DURATION_MS,
		"total_ms": JUICE_POPUP_DURATION_MS,
		"scale": scale,
	}
	juice_popups.append(d)

func _tick_juice_popups(dt: float) -> void:
	var dms: float = dt * 1000.0
	var next: Array = []
	for p_v: Variant in juice_popups:
		var p: Dictionary = p_v as Dictionary
		var ms: float = float(p.get("ms", 0.0)) - dms
		if ms <= 0.0:
			continue
		p["ms"] = ms
		next.append(p)
	juice_popups = next

func _init_ghosts() -> void:
	ghosts = []
	_rng.randomize()

	var house_tiles: Array = []
	for y: int in range(H):
		for x: int in range(FULL_W):
			if board.tile_at(x, y) == Tile.Id.GHOST_HOUSE:
				house_tiles.append(Vector2i(x, y))

	# Shuffle tiles.
	for i: int in range(house_tiles.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = house_tiles[i]
		house_tiles[i] = house_tiles[j]
		house_tiles[j] = tmp

	var spawn_fallback: Vector2i = Vector2i(int(floor(pac_pos.x)), int(floor(pac_pos.y)))
	var spawns: Array = []
	if house_tiles.size() > 0:
		for k: int in range(4):
			spawns.append(house_tiles[k % house_tiles.size()] as Vector2i)
	else:
		for k2: int in range(4):
			spawns.append(spawn_fallback)

	ghosts.append(_make_ghost("red", spawns[0] as Vector2i, DIR_LEFT))
	ghosts.append(_make_ghost("pink", spawns[1] as Vector2i, DIR_RIGHT))
	ghosts.append(_make_ghost("blue", spawns[2] as Vector2i, DIR_LEFT))
	ghosts.append(_make_ghost("orange", spawns[3] as Vector2i, DIR_RIGHT))
	_init_ghost_release_schedule()

func _make_ghost(id: String, pos: Vector2i, dir: int) -> RefCounted:
	var script: Script = load("res://scripts/ghosts/GhostState.gd") as Script
	var g: RefCounted = script.new() as RefCounted
	g.set("id", id)
	g.set("pos", pos)
	g.set("anim_from", pos)
	g.set("anim_to", pos)
	g.set("anim_t", 1.0)
	g.set("dest", Vector2i.ZERO)
	g.set("dir", dir)
	g.set("speed_tiles_per_sec", GHOST_TILES_PER_SEC)
	g.set("step_acc", 0.0)
	g.set("is_incapacitated", false)
	g.set("incapacitated_phase", "")
	g.set("incapacitated_roams_left", 0)
	g.set("incapacitated_wait_ms", 0.0)
	g.set("is_released", true)
	g.set("release_delay_ms", 0.0)
	return g

func _init_ghost_release_schedule() -> void:
	# Start-of-game staggered exits: red, pink, orange, blue (3s spacing).
	var order_index: Dictionary = {
		"red": 0,
		"pink": 1,
		"orange": 2,
		"blue": 3,
	}
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		var id: String = str(g.get("id"))
		var idx: int = int(order_index.get(id, 0))
		var delay_ms: float = float(idx) * GHOST_RELEASE_SPACING_MS
		g.set("release_delay_ms", delay_ms)
		g.set("is_released", idx == 0)

func _decrement_incap_wait_ms(dt: float) -> void:
	var dms: float = dt * 1000.0
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		if not bool(g.get("is_incapacitated")):
			continue
		if str(g.get("incapacitated_phase")) != INCAP_PHASE_WAITING:
			continue
		var w: float = float(g.get("incapacitated_wait_ms"))
		g.set("incapacitated_wait_ms", maxf(0.0, w - dms))

func _tick_ghost_release_timers(dt: float) -> void:
	var dms: float = dt * 1000.0
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		if g.get("is_released"):
			continue
		var delay_v: Variant = g.get("release_delay_ms")
		var left_ms_prev: float = 0.0
		if typeof(delay_v) == TYPE_FLOAT:
			left_ms_prev = delay_v as float
		elif typeof(delay_v) == TYPE_INT:
			left_ms_prev = 0.0 + (delay_v as int)
		var left_ms: float = maxf(0.0, left_ms_prev - dms)
		g.set("release_delay_ms", left_ms)
		if left_ms <= 0.0:
			g.set("is_released", true)

func _decrement_fruit_flash_ms(dt: float) -> void:
	var dms: float = dt * 1000.0
	left_side_fruit_flash_ms = maxf(0.0, left_side_fruit_flash_ms - dms)
	right_side_fruit_flash_ms = maxf(0.0, right_side_fruit_flash_ms - dms)
	left_side_fruit_sweep_ms = maxf(0.0, left_side_fruit_sweep_ms - dms)
	right_side_fruit_sweep_ms = maxf(0.0, right_side_fruit_sweep_ms - dms)

func _decrement_fruit_spawn_delays(dt: float) -> void:
	var dms: float = dt * 1000.0
	if _fruit_spawn_delay_left_ms > 0.0:
		_fruit_spawn_delay_left_ms = maxf(0.0, _fruit_spawn_delay_left_ms - dms)
	if _fruit_spawn_delay_right_ms > 0.0:
		_fruit_spawn_delay_right_ms = maxf(0.0, _fruit_spawn_delay_right_ms - dms)

func _update_hue_shift(dt: float) -> void:
	var diff: float = hue_shift_target - hue_shift_amount
	diff = fposmod(diff + 0.5, 1.0) - 0.5
	hue_shift_amount = fposmod(hue_shift_amount + diff * minf(1.0, FRUIT_HUE_SHIFT_LERP_PER_SEC * dt), 1.0)

func _reverse_all_ghost_dirs() -> void:
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		g.set("dir", _reverse_dir(int(g.get("dir"))))
		# Match glide to reversed `dir`: swap segment ends and mirror progress. Must update
		# `step_acc` too — `_step_ghosts` overwrites `anim_t` from `step_acc` every frame.
		# Torus tunnel wraps are not symmetric under swap (|dx|+|dy| != 1); snap to `pos` then.
		var af: Vector2i = g.get("anim_from") as Vector2i
		var at: Vector2i = g.get("anim_to") as Vector2i
		if _vec2i_eq(af, at):
			continue
		var acc: float = clampf(float(g.get("step_acc")), 0.0, 1.0)
		var manhattan: int = abs(at.x - af.x) + abs(at.y - af.y)
		if manhattan == 1:
			g.set("anim_from", at)
			g.set("anim_to", af)
			# Moves always keep `pos == anim_to` (committed tile = glide target). Swapping ends
			# without updating `pos` left stale `pos`; next move used wrong `anim_from` + `step_acc`.
			g.set("pos", af)
			g.set("step_acc", clampf(1.0 - acc, 0.0, 1.0))
		else:
			var p: Vector2i = _wrap_tile(g.get("pos") as Vector2i)
			g.set("anim_from", p)
			g.set("anim_to", p)
			g.set("pos", p)
			g.set("step_acc", 1.0)

func _reverse_dir(dir: int) -> int:
	if dir == DIR_UP:
		return DIR_DOWN
	if dir == DIR_DOWN:
		return DIR_UP
	if dir == DIR_LEFT:
		return DIR_RIGHT
	return DIR_LEFT

func _vec2i_eq(a: Vector2i, b: Vector2i) -> bool:
	return a.x == b.x and a.y == b.y

func _random_ghost_house_tile(exclude: Vector2i) -> Vector2i:
	var candidates: Array = []
	for y: int in range(H):
		for x: int in range(FULL_W):
			if board.tile_at(x, y) != Tile.Id.GHOST_HOUSE:
				continue
			if x == exclude.x and y == exclude.y:
				continue
			candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return random_walkable_tile_excluding(exclude)
	return candidates[_rng.randi_range(0, candidates.size() - 1)] as Vector2i

## Returns true if this ghost should skip normal chase AI this tick (web `updateGhostDestinations` incap block).
func _update_incap_ghost_dest(g: RefCounted, gpos: Vector2i, _gdir: int) -> bool:
	if not bool(g.get("is_incapacitated")):
		return false
	var phase_str: String = str(g.get("incapacitated_phase"))
	if phase_str == INCAP_PHASE_UNSTICK:
		var dest_u: Vector2i = g.get("dest") as Vector2i
		if board.is_wall(dest_u.x, dest_u.y):
			g.set("dest", _nearest_non_wall_tile_bfs(gpos))
		return true
	var roams_left: int = int(g.get("incapacitated_roams_left"))
	var wait_ms: float = float(g.get("incapacitated_wait_ms"))
	var on_gh: bool = board.is_ghost_house(gpos.x, gpos.y)
	var dest: Vector2i = g.get("dest") as Vector2i

	if phase_str == "":
		g.set("incapacitated_phase", INCAP_PHASE_ROAM)
		g.set("incapacitated_roams_left", 3)
		g.set("dest", random_walkable_tile_excluding(gpos))
		return true

	if phase_str == INCAP_PHASE_ROAM:
		if _vec2i_eq(gpos, dest):
			var next_roams: int = roams_left - 1
			if next_roams > 0:
				g.set("dest", random_walkable_tile_excluding(gpos))
				g.set("incapacitated_roams_left", next_roams)
			else:
				g.set("dest", _random_ghost_house_tile(gpos))
				g.set("incapacitated_phase", INCAP_PHASE_RETURN)
				g.set("incapacitated_roams_left", 0)
		return true

	if phase_str == INCAP_PHASE_RETURN:
		if _vec2i_eq(gpos, dest):
			if on_gh:
				var next_wait: float = 2000.0 + float(_rng.randi_range(0, 3000))
				g.set("incapacitated_wait_ms", next_wait)
				g.set("dest", _random_ghost_house_tile(gpos))
				g.set("incapacitated_phase", INCAP_PHASE_WAITING)
			else:
				g.set("dest", _random_ghost_house_tile(gpos))
		return true

	if phase_str == INCAP_PHASE_WAITING:
		if wait_ms <= 0.0:
			g.set("is_incapacitated", false)
			g.set("incapacitated_phase", "")
			g.set("incapacitated_roams_left", 0)
			g.set("incapacitated_wait_ms", 0.0)
			return false
		if _vec2i_eq(gpos, dest):
			g.set("dest", _random_ghost_house_tile(gpos))
		return true

	return false

func _update_ghost_destinations() -> void:
	var pt: Vector2i = pac_goal_tile()
	var red_pos: Vector2i = (ghosts[0] as RefCounted).get("pos") as Vector2i

	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		if not g.get("is_released"):
			continue
		var id: String = g.get("id") as String
		var gpos: Vector2i = g.get("pos") as Vector2i
		var gdir: int = int(g.get("dir"))
		var dest: Vector2i = g.get("dest") as Vector2i

		if _update_incap_ghost_dest(g, gpos, gdir):
			continue

		if id == "red":
			dest = pt
		elif id == "pink":
			dest = _pink_target_tile(gpos, gdir)
		elif id == "blue":
			dest = _blue_target_tile(red_pos)
		elif id == "orange":
			var near: bool = _manhattan(gpos, pt) <= ORANGE_SCATTER_DISTANCE
			if near:
				if gpos == dest or dest == pt:
					dest = random_walkable_tile_excluding(gpos)
			else:
				dest = pt

		g.set("dest", dest)

func _pink_target_tile(gpos: Vector2i, gdir: int) -> Vector2i:
	var pac: Vector2i = pac_tile()
	var v: Vector2 = _dir_to_vec(pac_dir)
	for k: int in range(4, -1, -1):
		var x: int = pac.x + int(v.x) * k
		var y: int = pac.y + int(v.y) * k
		if board.is_pac_blocked(x, y):
			continue
		var path: Array = find_path_bfs(gpos, Vector2i(x, y), gdir) as Array
		if path.size() > 0:
			return Vector2i(x, y)
	var fallback: Vector2i = pac_goal_tile()
	var p2: Array = find_path_bfs(gpos, fallback, gdir) as Array
	if p2.size() > 0:
		return fallback
	return random_walkable_tile_excluding(gpos)

func _blue_target_tile(red_pos: Vector2i) -> Vector2i:
	var pt: Vector2i = pac_goal_tile()
	var tx: int = pt.x + (pt.x - red_pos.x)
	var ty: int = pt.y + (pt.y - red_pos.y)
	if not board.is_pac_blocked(tx, ty):
		return Vector2i(tx, ty)
	return nearest_walkable_tile(Vector2i(tx, ty))

func pac_tile() -> Vector2i:
	# Toroidal wrap: continuous pac_pos can sit just outside [0,FULL_W) during tunnel exit before snap.
	var w: Vector2 = _pac_pos_wrapped_fractional()
	return Vector2i(int(floor(w.x)), int(floor(w.y)))

func pac_goal_tile() -> Vector2i:
	var pt: Vector2i = pac_tile()
	if not board.is_pac_blocked(pt.x, pt.y):
		return pt
	return nearest_walkable_tile(pt)

func nearest_walkable_tile(goal: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(0, 0)
	var best_d: int = 1 << 30
	for y: int in range(H):
		for x: int in range(FULL_W):
			if board.is_pac_blocked(x, y):
				continue
			var t: int = board.tile_at(x, y)
			if t == Tile.Id.EXIT or t == Tile.Id.GHOST_HOUSE:
				continue
			var dx: int = x - goal.x
			var dy: int = y - goal.y
			var d: int = dx * dx + dy * dy
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

func random_walkable_tile_excluding(exclude: Vector2i) -> Vector2i:
	var candidates: Array = []
	for y: int in range(H):
		for x: int in range(FULL_W):
			if x == exclude.x and y == exclude.y:
				continue
			if board.is_pac_blocked(x, y):
				continue
			var t: int = board.tile_at(x, y)
			if t == Tile.Id.EXIT or t == Tile.Id.GHOST_HOUSE:
				continue
			candidates.append(Vector2i(x, y))
	if candidates.size() == 0:
		return Vector2i(0, 0)
	var idx: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[idx] as Vector2i

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Power-pellet fear duration: 100% of base with full level clock, 50% of base when `time_remaining_s` is 0.
func _scaled_fear_duration_ms() -> float:
	var denom: float = LEVEL_DURATION_S
	if denom <= 0.0001:
		return FEAR_DURATION_MS * FEAR_DURATION_END_FRACTION
	var u: float = clampf(1.0 - time_remaining_s / denom, 0.0, 1.0)
	return FEAR_DURATION_MS * lerpf(1.0, FEAR_DURATION_END_FRACTION, u)

func _step_ghosts(dt: float) -> void:
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		if not g.get("is_released"):
			var acc_unreleased: float = float(g.get("step_acc"))
			var speed_u: float = float(g.get("speed_tiles_per_sec"))
			if fear_ms > 0.0:
				speed_u *= GHOST_FEAR_SPEED_MULT
			acc_unreleased += speed_u * dt
			var usteps: int = 0
			while acc_unreleased >= 1.0 and usteps < MAX_GHOST_TILE_STEPS_PER_FRAME:
				var moved_u: bool = _try_move_ghost_house_wander(g)
				if not moved_u:
					acc_unreleased = min(acc_unreleased, 1.0)
					break
				acc_unreleased -= 1.0
				usteps += 1
			g.set("step_acc", acc_unreleased)
			g.set("anim_t", clamp(acc_unreleased, 0.0, 1.0))
			continue
		var acc: float = float(g.get("step_acc"))
		var speed: float = float(g.get("speed_tiles_per_sec"))
		if bool(g.get("is_incapacitated")):
			speed *= 2.0
		elif fear_ms > 0.0:
			speed *= GHOST_FEAR_SPEED_MULT
		acc += speed * dt

		var steps: int = 0
		while acc >= 1.0 and steps < MAX_GHOST_TILE_STEPS_PER_FRAME:
			var moved: bool = _try_move_ghost_one_tile(g)
			if not moved:
				acc = min(acc, 1.0)
				break
			acc -= 1.0
			steps += 1

		g.set("step_acc", acc)
		g.set("anim_t", clamp(acc, 0.0, 1.0))

func _try_move_ghost_house_wander(g: RefCounted) -> bool:
	var pos: Vector2i = g.get("pos") as Vector2i
	var facing: int = int(g.get("dir"))
	var rev: int = _reverse_dir(facing)

	var candidates: Array[int] = []
	for ndir: int in [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]:
		if ndir == rev:
			continue
		var v: Vector2 = _dir_to_vec(ndir)
		var nx: int = pos.x + int(v.x)
		var ny: int = pos.y + int(v.y)
		if not board.is_ghost_step_blocked_opts(pos.x, pos.y, nx, ny, false, true):
			candidates.append(ndir)

	if candidates.is_empty():
		var rv: Vector2 = _dir_to_vec(rev)
		var rx: int = pos.x + int(rv.x)
		var ry: int = pos.y + int(rv.y)
		if board.is_ghost_step_blocked_opts(pos.x, pos.y, rx, ry, false, true):
			return false
		var next_r: Vector2i = _wrap_tile(Vector2i(rx, ry))
		g.set("dir", rev)
		g.set("anim_from", pos)
		g.set("anim_to", next_r)
		g.set("pos", next_r)
		return true

	var chosen: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var v2: Vector2 = _dir_to_vec(chosen)
	var nx2: int = pos.x + int(v2.x)
	var ny2: int = pos.y + int(v2.y)
	if board.is_ghost_step_blocked_opts(pos.x, pos.y, nx2, ny2, false, true):
		return false
	var next_cell: Vector2i = _wrap_tile(Vector2i(nx2, ny2))
	g.set("dir", chosen)
	g.set("anim_from", pos)
	g.set("anim_to", next_cell)
	g.set("pos", next_cell)
	return true

func _try_move_ghost_one_tile(g: RefCounted) -> bool:
	# Web: `isFeared = !isIncapacitated && fearMs > 0` — incapped ghosts use BFS, not fear wander.
	if bool(g.get("is_incapacitated")):
		if str(g.get("incapacitated_phase")) == INCAP_PHASE_UNSTICK:
			return _try_move_ghost_unstick(g)
		return _try_move_ghost_incap(g)
	if fear_ms > 0.0:
		return _try_move_ghost_fear(g)

	var pos: Vector2i = g.get("pos") as Vector2i
	var dest: Vector2i = g.get("dest") as Vector2i
	var facing: int = int(g.get("dir"))

	var path: Array = find_path_bfs(pos, dest, facing) as Array
	if path.size() < 2:
		dest = random_walkable_tile_excluding(pos)
		g.set("dest", dest)
		path = find_path_bfs(pos, dest, facing) as Array
		if path.size() < 2:
			return false

	var next_cell: Vector2i = path[1] as Vector2i
	var chosen_dir: int = _direction_from_step(pos, next_cell)
	if board.is_ghost_step_blocked(pos.x, pos.y, next_cell.x, next_cell.y):
		return false

	g.set("dir", chosen_dir)
	g.set("anim_from", pos)
	g.set("anim_to", next_cell)
	g.set("pos", next_cell)
	return true

func _try_move_ghost_incap(g: RefCounted) -> bool:
	var pos: Vector2i = g.get("pos") as Vector2i
	var dest: Vector2i = g.get("dest") as Vector2i
	var facing: int = int(g.get("dir"))
	var phase_str: String = str(g.get("incapacitated_phase"))
	var on_gh: bool = board.is_ghost_house(pos.x, pos.y)
	var allow_exit: bool = phase_str == INCAP_PHASE_RETURN
	var restrict_gh: bool = phase_str == INCAP_PHASE_WAITING and on_gh

	var path: Array = find_path_bfs(pos, dest, facing, allow_exit, restrict_gh) as Array
	if path.size() < 2:
		if restrict_gh:
			dest = _random_ghost_house_tile(pos)
		else:
			dest = random_walkable_tile_excluding(pos)
		g.set("dest", dest)
		path = find_path_bfs(pos, dest, facing, allow_exit, restrict_gh) as Array
		if path.size() < 2:
			return false

	var next_cell: Vector2i = path[1] as Vector2i
	var chosen_dir: int = _direction_from_step(pos, next_cell)
	if board.is_ghost_step_blocked_opts(pos.x, pos.y, next_cell.x, next_cell.y, allow_exit, restrict_gh):
		return false

	g.set("dir", chosen_dir)
	g.set("anim_from", pos)
	g.set("anim_to", next_cell)
	g.set("pos", next_cell)
	return true

func _repair_ghosts_if_inside_wall() -> void:
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		var pos: Vector2i = _wrap_tile(g.get("pos") as Vector2i)
		g.set("pos", pos)
		if board.tile_at(pos.x, pos.y) != Tile.Id.WALL:
			continue
		_begin_ghost_unstick_from_wall(g)

func _nearest_non_wall_tile_bfs(start: Vector2i) -> Vector2i:
	var s: Vector2i = _wrap_tile(start)
	if board.tile_at(s.x, s.y) != Tile.Id.WALL:
		return s
	var q: Array = [s]
	var qi: int = 0
	var visited: Dictionary = {}
	visited[_cell_key(s)] = true
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	while qi < q.size():
		var cur: Vector2i = q[qi] as Vector2i
		qi += 1
		for d: Vector2i in dirs:
			var n: Vector2i = _wrap_tile(Vector2i(cur.x + d.x, cur.y + d.y))
			var k: int = _cell_key(n)
			if visited.has(k):
				continue
			visited[k] = true
			if board.tile_at(n.x, n.y) != Tile.Id.WALL:
				return n
			q.append(n)
	return s

func _begin_ghost_unstick_from_wall(g: RefCounted) -> void:
	var pos: Vector2i = _wrap_tile(g.get("pos") as Vector2i)
	g.set("pos", pos)
	if board.tile_at(pos.x, pos.y) != Tile.Id.WALL:
		return
	if str(g.get("incapacitated_phase")) == INCAP_PHASE_UNSTICK:
		return
	var prev_incap_v: Variant = g.get("is_incapacitated")
	g.set("unstick_saved_incap", prev_incap_v == true)
	g.set("unstick_saved_phase", str(g.get("incapacitated_phase")))
	g.set("unstick_saved_roams", int(g.get("incapacitated_roams_left")))
	g.set("unstick_saved_wait_ms", float(g.get("incapacitated_wait_ms")))
	g.set("is_incapacitated", true)
	g.set("incapacitated_phase", INCAP_PHASE_UNSTICK)
	var goal: Vector2i = _nearest_non_wall_tile_bfs(pos)
	g.set("dest", goal)

func _finish_ghost_unstick(g: RefCounted) -> void:
	var saved_incap_v: Variant = g.get("unstick_saved_incap")
	var saved_incap: bool = saved_incap_v == true
	if saved_incap:
		var ph: String = str(g.get("unstick_saved_phase"))
		if ph == "" or ph == INCAP_PHASE_UNSTICK:
			ph = INCAP_PHASE_ROAM
		g.set("is_incapacitated", true)
		g.set("incapacitated_phase", ph)
		g.set("incapacitated_roams_left", int(g.get("unstick_saved_roams")))
		g.set("incapacitated_wait_ms", float(g.get("unstick_saved_wait_ms")))
	else:
		g.set("is_incapacitated", false)
		g.set("incapacitated_phase", "")
		g.set("incapacitated_roams_left", 0)
		g.set("incapacitated_wait_ms", 0.0)
	var pos: Vector2i = _wrap_tile(g.get("pos") as Vector2i)
	g.set("anim_from", pos)
	g.set("anim_to", pos)
	g.set("anim_t", 1.0)

func _try_move_ghost_unstick(g: RefCounted) -> bool:
	var pos: Vector2i = _wrap_tile(g.get("pos") as Vector2i)
	if board.tile_at(pos.x, pos.y) != Tile.Id.WALL:
		_finish_ghost_unstick(g)
		return false
	var dest: Vector2i = g.get("dest") as Vector2i
	var facing: int = int(g.get("dir"))
	var path: Array = find_path_bfs(pos, dest, facing, false, false, true) as Array
	if path.size() < 2:
		dest = _nearest_non_wall_tile_bfs(pos)
		g.set("dest", dest)
		path = find_path_bfs(pos, dest, facing, false, false, true) as Array
		if path.size() < 2:
			return false
	var next_cell: Vector2i = path[1] as Vector2i
	var chosen_dir: int = _direction_from_step(pos, next_cell)
	if board.is_ghost_step_blocked_opts(pos.x, pos.y, next_cell.x, next_cell.y, false, false, true):
		return false
	g.set("dir", chosen_dir)
	g.set("anim_from", pos)
	g.set("anim_to", next_cell)
	g.set("pos", next_cell)
	if _vec2i_eq(next_cell, dest):
		_finish_ghost_unstick(g)
	return true

## Random, non-reverse-first movement while feared (matches web `tryMoveGhostOneTile` fear branch).
func _try_move_ghost_fear(g: RefCounted) -> bool:
	var pos: Vector2i = g.get("pos") as Vector2i
	var facing: int = int(g.get("dir"))
	var dest: Vector2i = g.get("dest") as Vector2i
	var rev: int = _reverse_dir(facing)

	var candidates: Array[int] = []
	for ndir: int in [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]:
		if ndir == rev:
			continue
		var v: Vector2 = _dir_to_vec(ndir)
		var nx: int = pos.x + int(v.x)
		var ny: int = pos.y + int(v.y)
		if not board.is_ghost_step_blocked(pos.x, pos.y, nx, ny):
			candidates.append(ndir)

	if candidates.is_empty():
		var v2: Vector2 = _dir_to_vec(rev)
		var rx: int = pos.x + int(v2.x)
		var ry: int = pos.y + int(v2.y)
		if board.is_ghost_step_blocked(pos.x, pos.y, rx, ry):
			return false
		var next_r: Vector2i = _wrap_tile(Vector2i(rx, ry))
		g.set("dir", rev)
		g.set("anim_from", pos)
		g.set("anim_to", next_r)
		g.set("pos", next_r)
		return true

	var chosen: int = facing
	var has_facing: bool = false
	for c0: int in candidates:
		if c0 == facing:
			has_facing = true
			break
	if not has_facing:
		chosen = candidates[_rng.randi_range(0, candidates.size() - 1)]
	else:
		var turn_opts: Array[int] = []
		for c: int in candidates:
			if c != facing:
				turn_opts.append(c)
		if turn_opts.is_empty():
			chosen = facing
		else:
			chosen = facing if _rng.randf() < 0.65 else turn_opts[_rng.randi_range(0, turn_opts.size() - 1)]

	var vf: Vector2 = _dir_to_vec(chosen)
	var nx2: int = pos.x + int(vf.x)
	var ny2: int = pos.y + int(vf.y)
	if board.is_ghost_step_blocked(pos.x, pos.y, nx2, ny2):
		return false
	var next_cell: Vector2i = _wrap_tile(Vector2i(nx2, ny2))
	g.set("dir", chosen)
	g.set("anim_from", pos)
	g.set("anim_to", next_cell)
	g.set("pos", next_cell)
	g.set("dest", dest)
	return true

func _torus_dist_sq_tile(ax: float, ay: float, bx: float, by: float) -> float:
	var axw: float = fposmod(ax, float(FULL_W))
	var ayw: float = fposmod(ay, float(H))
	var bxw: float = fposmod(bx, float(FULL_W))
	var byw: float = fposmod(by, float(H))
	var dx_raw: float = abs(axw - bxw)
	var dy_raw: float = abs(ayw - byw)
	var dx: float = min(dx_raw, float(FULL_W) - dx_raw)
	var dy: float = min(dy_raw, float(H) - dy_raw)
	return dx * dx + dy * dy

func _ghost_visual_center_tile(g: RefCounted) -> Vector2:
	var from: Vector2i = g.get("anim_from") as Vector2i
	var to: Vector2i = g.get("anim_to") as Vector2i
	var t: float = float(g.get("anim_t"))
	return GhostInterpolation.visual_center_fractional(from, to, t, FULL_W, H)

func _check_pac_ghost_collisions() -> void:
	var wp: Vector2 = _pac_pos_wrapped_fractional()
	var r2: float = PAC_GHOST_COLLISION_RADIUS_TILES * PAC_GHOST_COLLISION_RADIUS_TILES

	if _pac_death_triggered:
		return

	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		if bool(g.get("is_incapacitated")):
			continue

		var gc: Vector2 = _ghost_visual_center_tile(g)
		if _torus_dist_sq_tile(wp.x, wp.y, gc.x, gc.y) > r2:
			continue

		if fear_ms > 0.0:
			ghost_eat_chain += 1
			var chain_pow: int = max(0, ghost_eat_chain - 1)
			var eat_score: int = GHOST_EATEN_COMBO_BASE * int(pow(2.0, float(chain_pow)))
			g.set("is_incapacitated", true)
			g.set("incapacitated_phase", INCAP_PHASE_ROAM)
			g.set("incapacitated_roams_left", 3)
			g.set("incapacitated_wait_ms", 0.0)
			g.set("dest", random_walkable_tile_excluding(g.get("pos") as Vector2i))
			score += eat_score
			_add_score_popup(pac_tile(), str(eat_score), Color(0.95, 0.98, 1.0, 1.0), 1.25)
			_add_hitstop(75.0)
			sfx_ghost_eaten = true
			return

		lives = max(0, lives - 1)
		_pac_death_triggered = true
		sfx_pac_death = true
		if lives <= 0:
			is_game_over = true
		return

func _direction_from_step(from: Vector2i, to: Vector2i) -> int:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if dx == 1:
		return DIR_RIGHT
	if dx == -1:
		return DIR_LEFT
	if dy == 1:
		return DIR_DOWN
	if dy == -1:
		return DIR_UP
	# Toroidal grid: BFS stores wrapped tiles, so one edge step is a multi-tile delta in indices.
	if dy == 0 and abs(dx) == FULL_W - 1:
		if from.x == FULL_W - 1 and to.x == 0:
			return DIR_RIGHT
		if from.x == 0 and to.x == FULL_W - 1:
			return DIR_LEFT
	if dx == 0 and abs(dy) == H - 1:
		if from.y == H - 1 and to.y == 0:
			return DIR_DOWN
		if from.y == 0 and to.y == H - 1:
			return DIR_UP
	return DIR_RIGHT

func _wrap_tile(p: Vector2i) -> Vector2i:
	var x: int = p.x % FULL_W
	if x < 0:
		x += FULL_W
	var y: int = p.y % H
	if y < 0:
		y += H
	return Vector2i(x, y)

func find_path_bfs(start: Vector2i, goal: Vector2i, facing: int, allow_exit_door: bool = false, restrict_to_ghost_house: bool = false, ignore_walls: bool = false) -> Array:
	var no_reverse: Array = _find_path_bfs_core(start, goal, facing, true, allow_exit_door, restrict_to_ghost_house, ignore_walls)
	if no_reverse.size() > 0:
		return no_reverse
	return _find_path_bfs_core(start, goal, facing, false, allow_exit_door, restrict_to_ghost_house, ignore_walls)

func _find_path_bfs_core(start: Vector2i, goal: Vector2i, facing: int, forbid_first_reverse: bool, allow_exit_door: bool, restrict_to_ghost_house: bool, ignore_walls: bool) -> Array:
	start = _wrap_tile(start)
	goal = _wrap_tile(goal)
	if start == goal:
		return [start]
	if board.is_wall(goal.x, goal.y):
		return []
	if restrict_to_ghost_house and board.tile_at(goal.x, goal.y) != Tile.Id.GHOST_HOUSE:
		return []

	var q: Array = [start]
	var qi: int = 0
	var visited: Dictionary = {}
	visited[_cell_key(start)] = true
	var parent: Dictionary = {}
	parent[_cell_key(start)] = null

	var skip_back: bool = forbid_first_reverse and _count_walkable_neighbors_opts(start, allow_exit_door, restrict_to_ghost_house, ignore_walls) > 1

	while qi < q.size():
		var cur: Vector2i = q[qi] as Vector2i
		qi += 1
		if cur == goal:
			return _reconstruct_path(parent, cur)

		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if board.is_ghost_step_blocked_opts(cur.x, cur.y, nx, ny, allow_exit_door, restrict_to_ghost_house, ignore_walls):
				continue
			if skip_back and cur == start and _is_back_neighbor(start, facing, nx, ny):
				continue
			var nex: Vector2i = _wrap_tile(Vector2i(nx, ny))
			var key: int = _cell_key(nex)
			if visited.has(key):
				continue
			visited[key] = true
			parent[key] = _cell_key(cur)
			q.append(nex)

	return []

func _reconstruct_path(parent: Dictionary, end: Vector2i) -> Array:
	var out: Array = []
	var k: Variant = _cell_key(end)
	while k != null:
		var key_int: int = int(k)
		var x: int = key_int % FULL_W
		var yf: float = float(key_int) / float(FULL_W)
		var y: int = int(floor(yf))
		out.push_front(Vector2i(x, y))
		k = parent.get(key_int)
	return out

func _cell_key(p: Vector2i) -> int:
	var wx: int = p.x % FULL_W
	if wx < 0:
		wx += FULL_W
	var wy: int = p.y % H
	if wy < 0:
		wy += H
	return wy * FULL_W + wx

func _count_walkable_neighbors_opts(p: Vector2i, allow_exit_door: bool, restrict_to_ghost_house: bool, ignore_walls: bool = false) -> int:
	var n: int = 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not board.is_ghost_step_blocked_opts(p.x, p.y, p.x + d.x, p.y + d.y, allow_exit_door, restrict_to_ghost_house, ignore_walls):
			n += 1
	return n

func _is_back_neighbor(start: Vector2i, facing: int, nx: int, ny: int) -> bool:
	var back: int = _opposite_dir(facing)
	var v: Vector2 = _dir_to_vec(back)
	return nx == start.x + int(v.x) and ny == start.y + int(v.y)

func _opposite_dir(dir: int) -> int:
	if dir == DIR_UP:
		return DIR_DOWN
	if dir == DIR_DOWN:
		return DIR_UP
	if dir == DIR_LEFT:
		return DIR_RIGHT
	return DIR_LEFT

func _advance_pac(dt: float) -> void:
	if pac_waiting_for_input and held_dirs_mask == 0:
		return
	var dir: int = _resolve_pac_dir_from_held()
	var v: Vector2 = _dir_to_vec(dir)
	var speed: float = _pac_speed_ramped

	var x: float = pac_pos.x
	var y: float = pac_pos.y

	var turned_90: bool = (dir != pac_dir) and (not _is_opposite_dir(pac_dir, dir))

	if turned_90:
		x = floor(x) + 0.5
		y = floor(y) + 0.5
	elif dir == DIR_LEFT or dir == DIR_RIGHT:
		y = floor(y) + 0.5
	else:
		x = floor(x) + 0.5

	var prev: Vector2 = Vector2(x, y)
	var nx: float = x + v.x * speed * dt
	var ny: float = y + v.y * speed * dt
	var clamped: Vector2 = _clamp_pac_axis(prev, Vector2(nx, ny), dir)

	# Limited warp snapping (matches web): allow leaving the visible range briefly.
	var sx: float = clamped.x
	var sy: float = clamped.y
	if sx < -SNAP_IF_BEYOND_TILES:
		sx += float(FULL_W)
	elif sx >= float(FULL_W) + SNAP_IF_BEYOND_TILES:
		sx -= float(FULL_W)
	if sy < -SNAP_IF_BEYOND_TILES:
		sy += float(H)
	elif sy >= float(H) + SNAP_IF_BEYOND_TILES:
		sy -= float(H)

	pac_pos = Vector2(sx, sy)
	pac_dir = dir

func _pac_pos_wrapped_fractional() -> Vector2:
	return Vector2(fposmod(pac_pos.x, float(FULL_W)), fposmod(pac_pos.y, float(H)))

func _collect_pellets() -> void:
	if vacuum_mode:
		_collect_pellets_vacuum()
		return

	var wp: Vector2 = _pac_pos_wrapped_fractional()
	var tx: int = int(floor(wp.x))
	var ty: int = int(floor(wp.y))
	# Pellet radius check matches web: squared distance to tile center (torus-safe coords).
	var cx: float = float(tx) + 0.5
	var cy: float = float(ty) + 0.5
	var dx: float = wp.x - cx
	var dy: float = wp.y - cy
	var r2: float = PELLET_COLLECT_RADIUS_TILES * PELLET_COLLECT_RADIUS_TILES
	if dx * dx + dy * dy > r2:
		return

	var row: Array = pellets[ty] as Array
	if row[tx] as bool:
		var is_power: bool = board.tile_at(tx, ty) == Tile.Id.POWER_PELLET
		row[tx] = false
		score += PELLET_SCORE
		if is_power:
			var already_in_fear: bool = fear_ms > 0.0
			fear_ms = _scaled_fear_duration_ms()
			if not already_in_fear:
				_reverse_all_ghost_dirs()
			sfx_power_pellet = true
			_add_hitstop(45.0)
		else:
			sfx_pellet = true
		if tx < 14:
			pellets_left_left = max(0, pellets_left_left - 1)
		else:
			pellets_left_right = max(0, pellets_left_right - 1)
		_sync_fruit_actives()

func _collect_pellets_vacuum() -> void:
	var wp: Vector2 = _pac_pos_wrapped_fractional()
	var r2: float = VACUUM_RADIUS_TILES * VACUUM_RADIUS_TILES
	for y: int in range(H):
		var row: Array = pellets[y] as Array
		for x: int in range(FULL_W):
			if not (row[x] as bool):
				continue
			var cx: float = float(x) + 0.5
			var cy: float = float(y) + 0.5
			if _torus_dist_sq_tile(wp.x, wp.y, cx, cy) > r2:
				continue
			var is_power: bool = board.tile_at(x, y) == Tile.Id.POWER_PELLET
			row[x] = false
			score += PELLET_SCORE
			if is_power:
				var already_in_fear: bool = fear_ms > 0.0
				fear_ms = _scaled_fear_duration_ms()
				if not already_in_fear:
					_reverse_all_ghost_dirs()
				sfx_power_pellet = true
				_add_hitstop(45.0)
			else:
				sfx_pellet = true
			if x < 14:
				pellets_left_left = max(0, pellets_left_left - 1)
			else:
				pellets_left_right = max(0, pellets_left_right - 1)
	_sync_fruit_actives()

func _can_collect_at_pac_position() -> bool:
	var wp: Vector2 = _pac_pos_wrapped_fractional()
	var tx: int = int(floor(wp.x))
	var ty: int = int(floor(wp.y))
	var cx: float = float(tx) + 0.5
	var cy: float = float(ty) + 0.5
	var dx: float = wp.x - cx
	var dy: float = wp.y - cy
	var r2: float = PELLET_COLLECT_RADIUS_TILES * PELLET_COLLECT_RADIUS_TILES
	return dx * dx + dy * dy <= r2

func _left_fruit_pos() -> Vector2i:
	return LEFT_FRUIT_SPAWN_LOCAL

func _right_fruit_pos() -> Vector2i:
	return Vector2i(2 * 14 - 1 - LEFT_FRUIT_SPAWN_LOCAL.x, LEFT_FRUIT_SPAWN_LOCAL.y)

func _sync_fruit_actives() -> void:
	# Fruit spawns on the opposite side of a cleared half, after a short delay.
	var right_cleared: bool = pellets_left_right == 0
	var left_cleared: bool = pellets_left_left == 0
	if right_cleared:
		if not _fruit_spawn_left_episode:
			_fruit_spawn_left_episode = true
			_fruit_spawn_delay_left_ms = FRUIT_SPAWN_DELAY_AFTER_SIDE_CLEAR_MS
	else:
		_fruit_spawn_left_episode = false
		_fruit_spawn_delay_left_ms = 0.0
	if left_cleared:
		if not _fruit_spawn_right_episode:
			_fruit_spawn_right_episode = true
			_fruit_spawn_delay_right_ms = FRUIT_SPAWN_DELAY_AFTER_SIDE_CLEAR_MS
	else:
		_fruit_spawn_right_episode = false
		_fruit_spawn_delay_right_ms = 0.0
	fruit_active_left = right_cleared and _fruit_spawn_delay_left_ms <= 0.0
	fruit_active_right = left_cleared and _fruit_spawn_delay_right_ms <= 0.0

func _load_half_layout_pool() -> void:
	_half_layouts = []
	var lg: LevelGrids = LevelGrids.load_from_path("res://assets/data/levelGrids.json")
	var names: PackedStringArray = lg.get_layout_names_sorted()
	for n: String in names:
		var half: Array = lg.get_layout(n)
		if half.is_empty():
			continue
		_half_layouts.append(_deep_copy_half_layout(half))

func _deep_copy_half_layout(src: Array) -> Array:
	var out: Array = []
	for y: int in range(src.size()):
		var row_src: Array = src[y] as Array
		var row: Array = []
		row.resize(row_src.size())
		for x: int in range(row_src.size()):
			row[x] = int(row_src[x])
		out.append(row)
	return out

func _random_half_layout_copy() -> Array:
	if _half_layouts.is_empty():
		return _deep_copy_half_layout(board.left)
	var idx: int = _rng.randi_range(0, _half_layouts.size() - 1)
	return _deep_copy_half_layout(_half_layouts[idx] as Array)

func _apply_half_refresh(side: String, new_left_half: Array) -> void:
	if side == "left":
		board.left = _deep_copy_half_layout(new_left_half)
	else:
		board.right = BoardModel._mirror_half(new_left_half)

	var right_side: bool = side == "right"
	var start_x: int = 14 if right_side else 0
	var end_x: int = 28 if right_side else 14
	var count: int = 0
	for y: int in range(H):
		var prow: Array = pellets[y] as Array
		for gx: int in range(start_x, end_x):
			var t: int = board.tile_at(gx, y)
			var has_pellet: bool = t == Tile.Id.PELLET or t == Tile.Id.POWER_PELLET
			prow[gx] = has_pellet
			if has_pellet:
				count += 1
	if right_side:
		pellets_left_right = count
	else:
		pellets_left_left = count
	board_revision += 1
	_repair_ghosts_if_inside_wall()

func _handle_fruit_collection() -> void:
	_sync_fruit_actives()
	if not _can_collect_at_pac_position():
		return

	var pt: Vector2i = pac_tile()
	var left_fruit: Vector2i = _left_fruit_pos()
	var right_fruit: Vector2i = _right_fruit_pos()

	if fruit_active_left and pt == left_fruit:
		var next_right_src: Array = _random_half_layout_copy()
		_apply_half_refresh("right", next_right_src)
		score += FRUIT_SCORE
		fruit_active_left = false
		right_side_fruit_flash_ms = FRUIT_SIDE_FLASH_DURATION_MS
		right_side_fruit_sweep_ms = FRUIT_SWEEP_DURATION_MS
		hue_shift_target = fposmod(hue_shift_target + FRUIT_HUE_SHIFT_STEP, 1.0)
		_add_score_popup(left_fruit, str(FRUIT_SCORE), Color(0.99, 0.72, 0.2, 1.0), 1.2)
		_add_hitstop(60.0)
		sfx_fruit_left = true
	elif fruit_active_right and pt == right_fruit:
		var next_left_src: Array = _random_half_layout_copy()
		_apply_half_refresh("left", next_left_src)
		score += FRUIT_SCORE
		fruit_active_right = false
		left_side_fruit_flash_ms = FRUIT_SIDE_FLASH_DURATION_MS
		left_side_fruit_sweep_ms = FRUIT_SWEEP_DURATION_MS
		hue_shift_target = fposmod(hue_shift_target + FRUIT_HUE_SHIFT_STEP, 1.0)
		_add_score_popup(right_fruit, str(FRUIT_SCORE), Color(0.99, 0.72, 0.2, 1.0), 1.2)
		_add_hitstop(60.0)
		sfx_fruit_right = true

	# Re-sync in same tick (web parity): allows both fruits to be visible if both halves are cleared.
	_sync_fruit_actives()

func _update_side_clear_progress(dt_s: float) -> void:
	# Simple smoothing toward target state (web has its own timing; this keeps visuals similar).
	var target_left: float = 1.0 if pellets_left_left == 0 else 0.0
	var target_right: float = 1.0 if pellets_left_right == 0 else 0.0
	var speed: float = 2.5
	left_side_clear_progress = move_toward(left_side_clear_progress, target_left, speed * dt_s)
	right_side_clear_progress = move_toward(right_side_clear_progress, target_right, speed * dt_s)

static func _dir_to_vec(dir: int) -> Vector2:
	if dir == DIR_UP:
		return Vector2(0.0, -1.0)
	if dir == DIR_DOWN:
		return Vector2(0.0, 1.0)
	if dir == DIR_LEFT:
		return Vector2(-1.0, 0.0)
	if dir == DIR_RIGHT:
		return Vector2(1.0, 0.0)
	return Vector2.ZERO

func _dirs_from_held_mask(mask: int) -> Array[int]:
	var out: Array[int] = []
	for d: int in [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]:
		if (mask & (1 << d)) != 0:
			out.append(d)
	return out

func _pick_priority_dir_first(candidates: Array[int]) -> int:
	var order: Array[int] = [DIR_UP, DIR_LEFT, DIR_RIGHT, DIR_DOWN]
	for d: int in order:
		if d in candidates:
			return d
	return candidates[0]

func _resolve_pac_dir_single(desired: int) -> int:
	var dir: int = pac_dir
	if desired == dir:
		return dir
	if _is_opposite_dir(dir, desired):
		return desired
	if _distance_to_tile_center(pac_pos.x, pac_pos.y) > TURN_CENTER_EPS_TILES:
		return dir
	if not _can_pac_start_turn(desired):
		return dir
	return desired

func _resolve_pac_dir_from_held() -> int:
	var held: Array[int] = _dirs_from_held_mask(held_dirs_mask)
	if held.is_empty():
		return pac_dir
	if pac_waiting_for_input:
		pac_waiting_for_input = false
	if held.size() == 1:
		return _resolve_pac_dir_single(held[0])

	var at_center: bool = _distance_to_tile_center(pac_pos.x, pac_pos.y) <= TURN_CENTER_EPS_TILES
	var valid: Array[int] = []
	for d: int in held:
		if _can_pac_start_turn(d):
			valid.append(d)
	if valid.is_empty():
		return pac_dir

	if not at_center:
		if pac_dir in held:
			return pac_dir
		return _resolve_pac_dir_single(_pick_priority_dir_first(held))

	if valid.size() == 1:
		return valid[0]

	# Same tile + two keys: `pac_dir` can flip every substep (straight ↔ turn), cancelling motion.
	# Latch one choice per tile until inputs or tile changes.
	var tile_i: Vector2i = Vector2i(int(floor(pac_pos.x)), int(floor(pac_pos.y)))
	if _dual_input_latch_tile != tile_i:
		_dual_input_latch_dir = -1
		_dual_input_latch_tile = tile_i
	if _dual_input_latch_dir >= 0 and _dual_input_latch_dir in valid:
		return _dual_input_latch_dir

	var chosen: int
	if pac_dir in valid:
		var turns: Array[int] = []
		for d: int in valid:
			if d != pac_dir:
				turns.append(d)
		if turns.size() > 0:
			chosen = _pick_priority_dir_first(turns)
		else:
			chosen = pac_dir
	else:
		chosen = _pick_priority_dir_first(valid)
	_dual_input_latch_dir = chosen
	return chosen

func _distance_to_tile_center(px: float, py: float) -> float:
	var cx: float = floor(px) + 0.5
	var cy: float = floor(py) + 0.5
	return abs(px - cx) + abs(py - cy)

func _can_pac_start_turn(dir: int) -> bool:
	var v: Vector2 = _dir_to_vec(dir)
	var gx: int = int(floor(pac_pos.x))
	var gy: int = int(floor(pac_pos.y))
	return not board.is_pac_blocked(gx + int(v.x), gy + int(v.y))

func _is_opposite_dir(a: int, b: int) -> bool:
	return (a == DIR_UP and b == DIR_DOWN) or (a == DIR_DOWN and b == DIR_UP) or (a == DIR_LEFT and b == DIR_RIGHT) or (a == DIR_RIGHT and b == DIR_LEFT)

func _clamp_pac_axis(prev: Vector2, next: Vector2, dir: int) -> Vector2:
	var v: Vector2 = _dir_to_vec(dir)
	var nx: float = next.x
	var ny: float = next.y

	if v.x != 0.0:
		var gy: int = int(floor(prev.y))
		var lane_y: float = float(gy) + 0.5
		ny = lane_y

		if v.x > 0.0:
			var from: int = int(floor(prev.x))
			var to: int = int(floor(nx))
			if board.is_pac_blocked(from + 1, gy):
				nx = min(nx, float(from) + 0.5)
			for c: int in range(from + 1, to + 1):
				if board.is_pac_blocked(c, gy):
					nx = min(nx, float(c) - 0.5)
					break
		else:
			var from_l: int = int(floor(prev.x))
			var to_l: int = int(floor(nx))
			if board.is_pac_blocked(from_l - 1, gy):
				nx = max(nx, float(from_l) + 0.5)
			for c2: int in range(from_l - 1, to_l - 1, -1):
				if board.is_pac_blocked(c2, gy):
					nx = max(nx, float(c2) + 1.5)
					break

		if board.is_pac_blocked(int(floor(nx)), gy):
			nx = float(int(floor(prev.x))) + 0.5

	elif v.y != 0.0:
		var gx: int = int(floor(prev.x))
		var lane_x: float = float(gx) + 0.5
		nx = lane_x

		if v.y > 0.0:
			var from_y: int = int(floor(prev.y))
			var to_y: int = int(floor(ny))
			if board.is_pac_blocked(gx, from_y + 1):
				ny = min(ny, float(from_y) + 0.5)
			for r: int in range(from_y + 1, to_y + 1):
				if board.is_pac_blocked(gx, r):
					ny = min(ny, float(r) - 0.5)
					break
		else:
			var from_yu: int = int(floor(prev.y))
			var to_yu: int = int(floor(ny))
			if board.is_pac_blocked(gx, from_yu - 1):
				ny = max(ny, float(from_yu) + 0.5)
			for r2: int in range(from_yu - 1, to_yu - 1, -1):
				if board.is_pac_blocked(gx, r2):
					ny = max(ny, float(r2) + 1.5)
					break

		if board.is_pac_blocked(gx, int(floor(ny))):
			ny = float(int(floor(prev.y))) + 0.5

	return Vector2(nx, ny)

func reset_after_death() -> void:
	# Reset actors as if a new round started; preserve pellets/score/time.
	var preferred_spawn: Vector2i = Vector2i(13, 26)
	var spawn_tile: Vector2i = board.nearest_pac_spawn_tile(preferred_spawn)
	pac_pos = Vector2(float(spawn_tile.x) + 0.5, float(spawn_tile.y) + 0.5)
	pac_dir = DIR_LEFT
	desired_dir = pac_dir
	held_dirs_mask = 0
	_dual_input_latch_dir = -1
	_dual_input_latch_tile = Vector2i(-999, -999)
	pac_waiting_for_input = true
	fear_ms = 0.0
	ghost_eat_chain = 0
	_pac_death_triggered = false
	_init_ghosts()
