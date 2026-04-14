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

var score_label: Control
var time_label: Label
@onready var walls_view: Node2D = $Board
@onready var wall_lights_view: Node2D = $WallLights
@onready var wall_darken_view: Node2D = $WallDarken
@onready var tile_overlay_view: Node2D = $TileOverlay
@onready var pac_view: Node2D = $Entities/Pac
@onready var ghosts_view: Node2D = $Entities/Ghosts
@onready var ghost_paths_view: Node2D = $Debug/GhostPaths
@onready var score_popups_view: Node2D = $Debug/ScorePopups
@onready var game_audio: GameAudio = $Audio

var _model: RefCounted = null
var _last_board_revision: int = 0

func _ready() -> void:
	# Main adds the HUD label to group `game_status_hud` in _ready; run boot after that.
	call_deferred("_boot_after_main")

func _boot_after_main() -> void:
	_accumulator_s = 0.0
	_sim_time_s = 0.0
	_hitstop_left_s = 0.0
	score_label = get_tree().get_first_node_in_group("game_score_hud") as Control
	time_label = get_tree().get_first_node_in_group("game_time_hud") as Label
	if score_label == null or time_label == null:
		push_error("GameRoot: Main should register ScoreLabel/TimeLabel groups.")
	else:
		_set_score_label_raw("Loading...")
		time_label.text = "--"
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
		if score_popups_view.has_method("set_model"):
			score_popups_view.call("set_model", _model)
		if score_label != null:
			_set_score_label_score(0)
		if time_label != null:
			time_label.text = "600"
		if game_audio != null:
			game_audio.try_start_music()
	else:
		if score_label != null:
			_set_score_label_raw("Load Error")
		if time_label != null:
			time_label.text = "--"

func _physics_process(delta: float) -> void:
	_handle_input()
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
		if score_label != null:
			if bool(_model.get("is_game_over")):
				_set_score_label_raw("GAME OVER   Score: %d" % score)
			else:
				_set_score_label_score(score)
		if time_label != null:
			time_label.text = str(int(time_remaining_s))

func _apply_hud_juice(_delta: float) -> void:
	if score_label == null:
		return
	var low_time: bool = false
	if _model != null:
		low_time = float(_model.get("time_remaining_s")) <= 10.0 and not bool(_model.get("is_game_over"))
	score_label.scale = Vector2.ONE
	if low_time:
		if time_label != null:
			var a: float = 0.5 + 0.5 * sin(_sim_time_s * TAU * 2.2)
			time_label.modulate = Color(1.0, 0.83 + 0.12 * a, 0.83 + 0.12 * a, 1.0)
		score_label.modulate = Color(1, 1, 1, 1)
	else:
		if time_label != null:
			time_label.modulate = Color(1, 1, 1, 1)
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

func _handle_input() -> void:
	if _model == null:
		return
	var next_dir: int = int(_model.get("desired_dir"))
	if Input.is_action_pressed("move_up"):
		next_dir = DIR_UP
	elif Input.is_action_pressed("move_down"):
		next_dir = DIR_DOWN
	elif Input.is_action_pressed("move_left"):
		next_dir = DIR_LEFT
	elif Input.is_action_pressed("move_right"):
		next_dir = DIR_RIGHT
	_model.call("set_desired_dir", next_dir)
