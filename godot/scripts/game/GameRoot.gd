extends Node2D

const FIXED_DT: float = 1.0 / 60.0
const MAX_STEPS_PER_FRAME: int = 8

const DIR_UP: int = 0
const DIR_DOWN: int = 1
const DIR_LEFT: int = 2
const DIR_RIGHT: int = 3

var _accumulator_s: float = 0.0
var _sim_time_s: float = 0.0
var _hitstop_left_s: float = 0.0
var _ui_time_remaining_s: float = float(Constants.LEVEL_DURATION_S)

var score_label: Control
var time_label: Label
var center_time_label: Label
@onready var walls_view: Node2D = $Board
@onready var wall_lights_view: Node2D = $WallLights
@onready var wall_darken_view: Node2D = $WallDarken
@onready var tile_overlay_view: Node2D = $TileOverlay
@onready var play_area_background_view: Node2D = $PlayAreaBackground
@onready var board_frame_view: Node2D = $BoardFrame
@onready var pac_view: Node2D = $Entities/Pac
@onready var ghosts_view: Node2D = $Entities/Ghosts
@onready var ghost_paths_view: Node2D = $Debug/GhostPaths
@onready var score_popups_view: Node2D = $Debug/ScorePopups
@onready var game_audio: GameAudio = $Audio

var _model: RefCounted = null
var _last_board_revision: int = 0
var _show_ghost_paths: bool = false
var _toggle_paths_key_was_down: bool = false
var _vacuum_key_was_down: bool = false
var _death_freeze: bool = false
var _last_timer_display_int: int = -1
var _timer_pulse_tween: Tween

func _ready() -> void:
	# Main adds the HUD label to group `game_status_hud` in _ready; run boot after that.
	call_deferred("_boot_after_main")

func _boot_after_main() -> void:
	_accumulator_s = 0.0
	_sim_time_s = 0.0
	_hitstop_left_s = 0.0
	_ui_time_remaining_s = float(Constants.LEVEL_DURATION_S)
	_show_ghost_paths = false
	_toggle_paths_key_was_down = false
	_vacuum_key_was_down = false
	score_label = get_tree().get_first_node_in_group("game_score_hud") as Control
	time_label = get_tree().get_first_node_in_group("game_time_hud") as Label
	center_time_label = get_tree().get_first_node_in_group("game_time_center_hud") as Label
	if score_label == null or time_label == null or center_time_label == null:
		push_error("GameRoot: Main should register ScoreLabel/TimeLabel groups.")
	else:
		_set_score_label_raw("Loading...")
		time_label.text = "--"
		center_time_label.visible = false
	if walls_view.has_method("load_default_layout"):
		walls_view.call("load_default_layout")
		var board: BoardModel = walls_view.call("get_board_model") as BoardModel
		var model_script: Script = load("res://scripts/game/GameModel.gd") as Script
		_model = model_script.new() as RefCounted
		_model.call("init_from_board", board)
		_last_board_revision = int(_model.get("board_revision"))
		if pac_view.has_method("set_model"):
			pac_view.call("set_model", _model)
		if walls_view.has_method("set_model"):
			walls_view.call("set_model", _model)
		if play_area_background_view.has_method("set_model"):
			play_area_background_view.call("set_model", _model)
		if board_frame_view.has_method("set_model"):
			board_frame_view.call("set_model", _model)
		if wall_lights_view.has_method("set_model"):
			wall_lights_view.call("set_model", _model)
		if wall_darken_view.has_method("set_model"):
			wall_darken_view.call("set_model", _model)
		if tile_overlay_view.has_method("set_model"):
			tile_overlay_view.call("set_model", _model)

		if wall_lights_view.has_method("set_board"):
			# (wall lights now uses wall mask)
			pass
		if wall_darken_view.has_method("set_wall_mask"):
			pass
		if tile_overlay_view.has_method("set_board"):
			tile_overlay_view.call("set_board", board)

		# Provide wall mask to shader overlays once built.
		var mask: Texture2D = walls_view.call("get_wall_mask_texture") as Texture2D
		if mask != null:
			wall_lights_view.call("set_wall_mask", mask)
			wall_darken_view.call("set_wall_mask", mask)
		if ghosts_view.has_method("set_model"):
			ghosts_view.call("set_model", _model)
		if ghost_paths_view.has_method("set_model"):
			ghost_paths_view.call("set_model", _model)
		ghost_paths_view.visible = _show_ghost_paths
		if score_popups_view.has_method("set_model"):
			score_popups_view.call("set_model", _model)
		if score_label != null:
			_set_score_label_score(0)
		if time_label != null:
			_update_timer_hud(float(Constants.LEVEL_DURATION_S))
		if game_audio != null:
			if game_audio.try_begin_start_song_blocking(get_tree()):
				game_audio.start_song_finished.connect(_on_start_song_finished_boot, CONNECT_ONE_SHOT)
			else:
				game_audio.try_start_music()
	else:
		if score_label != null:
			_set_score_label_raw("Load Error")
		if time_label != null:
			time_label.text = "--"
		if center_time_label != null:
			center_time_label.visible = false

func _physics_process(delta: float) -> void:
	if _death_freeze:
		# Freeze simulation until death audio completes; keep HUD + music running.
		_sim_time_s += delta
		_ui_time_remaining_s = maxf(0.0, _ui_time_remaining_s - delta)
		_update_timer_hud(_ui_time_remaining_s)
		if game_audio != null:
			game_audio.update_ghost_ambience(null, delta)
		_apply_hud_juice(delta)
		return
	_handle_input()
	if game_audio != null:
		game_audio.update_ghost_ambience(_model, delta)
	if _hitstop_left_s > 0.0:
		_hitstop_left_s = maxf(0.0, _hitstop_left_s - delta)
		_apply_hud_juice(delta)
		return
	_accumulator_s += delta

	var steps: int = 0
	while _accumulator_s >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
		_step_simulation(FIXED_DT)
		_accumulator_s -= FIXED_DT
		steps += 1
	_apply_hud_juice(delta)

func _step_simulation(dt: float) -> void:
	_sim_time_s += dt
	if _model != null:
		var prev_time_remaining_s: float = float(_model.get("time_remaining_s"))
		_model.call("step", dt)
		if game_audio != null:
			if bool(_model.get("sfx_pac_death")):
				_begin_death_freeze()
				return
			game_audio.play_step_sfx(_model)
			var next_time_remaining_s: float = float(_model.get("time_remaining_s"))
			game_audio.maybe_play_low_time_warning(int(prev_time_remaining_s), int(next_time_remaining_s))
		var board_rev: int = int(_model.get("board_revision"))
		if board_rev != _last_board_revision:
			_last_board_revision = board_rev
			if walls_view.has_method("rebuild_after_board_change"):
				walls_view.call("rebuild_after_board_change")
			var mask: Texture2D = walls_view.call("get_wall_mask_texture") as Texture2D
			if mask != null:
				wall_lights_view.call("set_wall_mask", mask)
				wall_darken_view.call("set_wall_mask", mask)
		var score: int = int(_model.get("score"))
		var hs_ms: float = float(_model.get("hitstop_ms"))
		_hitstop_left_s = maxf(_hitstop_left_s, hs_ms / 1000.0)
		var time_remaining_s: float = float(_model.get("time_remaining_s"))
		_ui_time_remaining_s = time_remaining_s
		if score_label != null:
			if bool(_model.get("is_game_over")):
				_set_score_label_raw("GAME OVER   Score: %d" % score)
			else:
				_set_score_label_score(score)
		_update_timer_hud(time_remaining_s)

func _apply_hud_juice(_delta: float) -> void:
	if score_label == null:
		return
	var low_time: bool = false
	if _death_freeze:
		low_time = _ui_time_remaining_s <= 10.0 and (_model == null or not bool(_model.get("is_game_over")))
	elif _model != null:
		low_time = float(_model.get("time_remaining_s")) <= 10.0 and not bool(_model.get("is_game_over"))
	score_label.scale = Vector2.ONE
	if low_time:
		if time_label != null:
			var a: float = 0.5 + 0.5 * sin(_sim_time_s * TAU * 2.2)
			time_label.modulate = Color(1.0, 0.83 + 0.12 * a, 0.83 + 0.12 * a, 1.0)
		if center_time_label != null:
			var b: float = 0.5 + 0.5 * sin(_sim_time_s * TAU * 2.2)
			center_time_label.modulate = Color(1.0, 0.90 + 0.08 * b, 0.90 + 0.08 * b, 0.56)
		score_label.modulate = Color(1, 1, 1, 1)
	else:
		if time_label != null:
			time_label.modulate = Color(1, 1, 1, 1)
		if center_time_label != null:
			center_time_label.modulate = Color(1, 1, 1, 0.56)
		score_label.modulate = Color(1, 1, 1, 1)

func _set_score_label_raw(text: String) -> void:
	if score_label == null:
		return
	if score_label.has_method("set_raw_text"):
		score_label.call("set_raw_text", text)

func _set_score_label_score(score: int) -> void:
	if score_label == null:
		return
	if score_label.has_method("set_score"):
		score_label.call("set_score", score)

func _update_timer_hud(time_s: float) -> void:
	var t_i: int = ceili(maxf(0.0, time_s))
	var prev_i: int = _last_timer_display_int
	if center_time_label != null:
		center_time_label.text = str(t_i)
		center_time_label.visible = t_i <= 10
	if time_label != null:
		time_label.text = str(t_i)
		time_label.visible = t_i > 10
	# Pulse the large center timer when the countdown loses a second (last 10s only).
	if prev_i >= 0 and t_i < prev_i and t_i <= 10:
		_pulse_timer_label(center_time_label)
	_last_timer_display_int = t_i

func _pulse_timer_label(l: Label) -> void:
	if l == null:
		return
	if _timer_pulse_tween != null and is_instance_valid(_timer_pulse_tween):
		_timer_pulse_tween.kill()
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE
	_timer_pulse_tween = create_tween()
	_timer_pulse_tween.tween_property(l, "scale", Vector2(2, 2), 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_timer_pulse_tween.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_model() -> RefCounted:
	return _model

func _on_start_song_finished_boot() -> void:
	_accumulator_s = 0.0
	if game_audio != null:
		game_audio.try_start_music()

func _begin_death_freeze() -> void:
	if _death_freeze:
		return
	_death_freeze = true
	_accumulator_s = 0.0
	if game_audio != null:
		# If this death ends the game, stop the song immediately (death SFX still plays).
		if _model != null and bool(_model.get("is_game_over")):
			game_audio.stop_music()
		game_audio.pac_death_finished.connect(_on_pac_death_finished, CONNECT_ONE_SHOT)
		game_audio.play_pac_death()

func _on_pac_death_finished() -> void:
	_death_freeze = false
	_accumulator_s = 0.0
	var game_over: bool = false
	if _model != null:
		game_over = bool(_model.get("is_game_over"))
		if not game_over:
			_model.set("time_remaining_s", _ui_time_remaining_s)
			_model.call("reset_after_death")
	if game_audio != null and not game_over:
		game_audio.try_start_music()

func _handle_input() -> void:
	var toggle_down: bool = Input.is_key_pressed(KEY_P)
	if toggle_down and not _toggle_paths_key_was_down:
		_show_ghost_paths = not _show_ghost_paths
		if ghost_paths_view != null:
			ghost_paths_view.visible = _show_ghost_paths
	_toggle_paths_key_was_down = toggle_down

	var vacuum_down: bool = Input.is_key_pressed(KEY_V)
	if vacuum_down and not _vacuum_key_was_down and _model != null:
		var cur_vacuum: bool = bool(_model.get("vacuum_mode"))
		_model.set("vacuum_mode", not cur_vacuum)
	_vacuum_key_was_down = vacuum_down

	if _model == null:
		return
	var mask: int = 0
	if Input.is_action_pressed("move_up"):
		mask |= 1 << DIR_UP
	if Input.is_action_pressed("move_down"):
		mask |= 1 << DIR_DOWN
	if Input.is_action_pressed("move_left"):
		mask |= 1 << DIR_LEFT
	if Input.is_action_pressed("move_right"):
		mask |= 1 << DIR_RIGHT
	_model.call("set_held_dirs_mask", mask)
