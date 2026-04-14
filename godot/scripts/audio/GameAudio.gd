extends Node
class_name GameAudio

const LOW_TIME_WARNING_SEC: int = 10

const MUSIC_PATH: String = "res://assets/audio/music_loop.mp3"
const PELLET_PATH: String = "res://assets/audio/pellet.mp3"
const POWER_PELLET_PATH: String = "res://assets/audio/power_pellet.mp3"
const FRUIT_PATH: String = "res://assets/audio/fruit.mp3"
const GHOST_EATEN_PATH: String = "res://assets/audio/ghost_eaten.mp3"
const GAME_OVER_PATH: String = "res://assets/audio/game_over.mp3"
const LOW_TIME_PATH: String = "res://assets/audio/low_time_warning.mp3"

var _warned_missing: Dictionary = {}
var _music_started: bool = false

var _music_player: AudioStreamPlayer
var _pellet_player: AudioStreamPlayer
var _pellet_player_alt: AudioStreamPlayer
var _power_pellet_player: AudioStreamPlayer
var _fruit_player: AudioStreamPlayer
var _ghost_eaten_player: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer
var _low_time_player: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pellet_toggle: bool = false

func _ready() -> void:
	_music_player = _make_player("Music", MUSIC_PATH, 0.22, true)
	_pellet_player = _make_player("Pellet", PELLET_PATH, 0.38, false)
	_pellet_player_alt = _make_player("PelletAlt", PELLET_PATH, 0.34, false)
	_power_pellet_player = _make_player("PowerPellet", POWER_PELLET_PATH, 0.42, false)
	_fruit_player = _make_player("Fruit", FRUIT_PATH, 0.45, false)
	_ghost_eaten_player = _make_player("GhostEaten", GHOST_EATEN_PATH, 0.4, false)
	_game_over_player = _make_player("GameOver", GAME_OVER_PATH, 0.5, false)
	_low_time_player = _make_player("LowTime", LOW_TIME_PATH, 0.35, false)
	_rng.randomize()

func _make_player(node_name: String, res_path: String, volume_linear: float, looped: bool) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = "Master"
	p.volume_db = linear_to_db(maxf(0.0001, volume_linear))
	p.stream = _load_audio_stream_or_null(res_path)
	if p.stream is AudioStreamMP3:
		(p.stream as AudioStreamMP3).loop = looped
	elif p.stream is AudioStreamOggVorbis:
		(p.stream as AudioStreamOggVorbis).loop = looped
	add_child(p)
	return p

func _load_audio_stream_or_null(res_path: String) -> AudioStream:
	if not ResourceLoader.exists(res_path):
		if not _warned_missing.has(res_path):
			_warned_missing[res_path] = true
			push_warning("Audio missing (safe to ignore until assets are added): %s" % res_path)
		return null
	var stream: AudioStream = load(res_path) as AudioStream
	if stream == null and not _warned_missing.has(res_path):
		_warned_missing[res_path] = true
		push_warning("Audio failed to load: %s" % res_path)
	return stream

func _play_if_ready(p: AudioStreamPlayer, pitch_scale: float = 1.0) -> void:
	if p == null or p.stream == null:
		return
	p.pitch_scale = pitch_scale
	p.play()

func try_start_music() -> void:
	if _music_started:
		return
	if _music_player == null or _music_player.stream == null:
		return
	if not _music_player.playing:
		_music_player.play()
		_music_started = true

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_music_started = false

func play_step_sfx(model: RefCounted) -> void:
	if model == null:
		return
	if bool(model.get("sfx_power_pellet")):
		_play_if_ready(_power_pellet_player, 1.0)
	elif bool(model.get("sfx_pellet")):
		_pellet_toggle = not _pellet_toggle
		var p: AudioStreamPlayer = _pellet_player_alt if _pellet_toggle else _pellet_player
		var pitch: float = 0.93 + _rng.randf() * 0.14
		_play_if_ready(p, pitch)
	if bool(model.get("sfx_fruit_left")) or bool(model.get("sfx_fruit_right")):
		_play_if_ready(_fruit_player, 1.0)
	if bool(model.get("sfx_ghost_eaten")):
		var chain: int = int(model.get("ghost_eat_chain"))
		var pitch_chain: float = 1.0 + minf(0.32, float(max(0, chain - 1)) * 0.07)
		_play_if_ready(_ghost_eaten_player, pitch_chain)
	if bool(model.get("sfx_game_over")):
		stop_music()
		_play_if_ready(_game_over_player, 1.0)

func maybe_play_low_time_warning(prev_sec: int, next_sec: int) -> void:
	if prev_sec > LOW_TIME_WARNING_SEC and next_sec <= LOW_TIME_WARNING_SEC and next_sec > 0:
		_play_if_ready(_low_time_player)
