extends Node
class_name GameAudio

signal start_song_finished
signal pac_death_finished

## Paths without extension — first match wins: .wav, then .mp3, then .ogg
const MUSIC_BASE: String = "res://assets/audio/music_loop"
const START_SONG_BASE: String = "res://assets/audio/start_song"
const PELLET_BASE: String = "res://assets/audio/pellet"
const PELLET_ALT_BASE: String = "res://assets/audio/pellet_alt"
const FRUIT_BASE: String = "res://assets/audio/fruit"
const GHOST_EATEN_BASE: String = "res://assets/audio/ghost_eaten"
const GAME_OVER_BASE: String = "res://assets/audio/game_over"
const PAC_DEATH_BASE: String = "res://assets/audio/pac_death"
const GHOST_ALIVE_LOOP_BASE: String = "res://assets/audio/ghost_alive"
const GHOST_FEAR_LOOP_BASE: String = "res://assets/audio/ghost_fear"
const GHOST_INCAP_LOOP_BASE: String = "res://assets/audio/ghost_incapacitated"

const GHOST_BASE_VOLUME_ALIVE: float = 0.18
## Extra linear gain per additional living ghost on the global alive loop (after the first).
const GHOST_ALIVE_PER_EXTRA_GHOST: float = 0.16
const GHOST_ALIVE_GLOBAL_GAIN_CAP: float = 0.42
## Single full-mix loop while `GameModel.fear_ms` > 0 (per-ghost players are silent then).
const GHOST_FEAR_GLOBAL_VOLUME_LINEAR: float = 0.24
const GHOST_BASE_VOLUME_INCAP: float = 0.05
## Distance at which ghost ambience reaches ~0 (tile units). Larger = audible from farther away.
const GHOST_HEAR_RADIUS_TILES: float = 44.0
## 1.0 = linear falloff; >1.0 = quieter when far; was effectively 2.0 (k*k).
const GHOST_DISTANCE_ATTENUATION_EXP: float = 1.35
const GHOST_VOLUME_SMOOTH_PER_SEC: float = 10.0

var _warned_missing: Dictionary = {}
var _music_started: bool = false

var _music_player: AudioStreamPlayer
var _pellet_player: AudioStreamPlayer
var _pellet_player_alt: AudioStreamPlayer
var _fruit_player: AudioStreamPlayer
var _ghost_eaten_player: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer
var _pac_death_player: AudioStreamPlayer
var _ghost_state_streams: Dictionary = {}
## Per-ghost slots used only for `incapacitated` loops (alive uses `_ghost_alive_global_player`).
var _ghost_incap_loop_players: Array[AudioStreamPlayer] = []
var _ghost_incap_loop_gain_linear: Array[float] = []
var _ghost_alive_global_player: AudioStreamPlayer
var _ghost_alive_global_gain_linear: float = 0.0
var _fear_global_player: AudioStreamPlayer
var _fear_global_gain_linear: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pellet_toggle: bool = false
var _start_song_player: AudioStreamPlayer

func _ready() -> void:
	_music_player = _make_player("Music", MUSIC_BASE, 0.22, true)
	_pellet_player = _make_player("Pellet", PELLET_BASE, 0.15, false)
	_pellet_player_alt = _make_player("PelletAlt", PELLET_ALT_BASE, 0.13, false)
	if _pellet_player_alt.stream == null and _pellet_player.stream != null:
		_pellet_player_alt.stream = _pellet_player.stream
	_fruit_player = _make_player("Fruit", FRUIT_BASE, 0.45, false)
	_ghost_eaten_player = _make_player("GhostEaten", GHOST_EATEN_BASE, 0.4, false)
	_game_over_player = _make_player("GameOver", GAME_OVER_BASE, 0.5, false)
	_pac_death_player = _make_player("PacDeath", PAC_DEATH_BASE, 0.6, false)
	if _pac_death_player != null:
		_pac_death_player.finished.connect(func() -> void: pac_death_finished.emit())
	_ghost_state_streams["alive"] = _load_audio_stream_from_base(GHOST_ALIVE_LOOP_BASE, true)
	_ghost_state_streams["incapacitated"] = _load_audio_stream_from_base(GHOST_INCAP_LOOP_BASE, true)
	_ghost_alive_global_player = AudioStreamPlayer.new()
	_ghost_alive_global_player.name = "GhostAliveGlobal"
	_ghost_alive_global_player.bus = "Master"
	_ghost_alive_global_player.volume_db = linear_to_db(0.0001)
	_ghost_alive_global_player.stream = _ghost_state_streams["alive"] as AudioStream
	add_child(_ghost_alive_global_player)
	_ghost_alive_global_gain_linear = 0.0
	_fear_global_player = AudioStreamPlayer.new()
	_fear_global_player.name = "GhostFearGlobal"
	_fear_global_player.bus = "Master"
	_fear_global_player.volume_db = linear_to_db(0.0001)
	_fear_global_player.stream = _load_audio_stream_from_base(GHOST_FEAR_LOOP_BASE, true)
	add_child(_fear_global_player)
	_fear_global_gain_linear = 0.0
	_init_ghost_incap_loop_players(4)
	_start_song_player = AudioStreamPlayer.new()
	_start_song_player.name = "StartSong"
	_start_song_player.bus = "Master"
	_start_song_player.volume_db = linear_to_db(0.4)
	var start_stream: AudioStream = _resolve_audio_stream(START_SONG_BASE)
	_apply_stream_loop(start_stream, false)
	_start_song_player.stream = start_stream
	add_child(_start_song_player)
	if start_stream != null:
		_start_song_player.finished.connect(_on_start_song_finished)
	_rng.randomize()

func _make_player(node_name: String, base_path_without_ext: String, volume_linear: float, looped: bool) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = "Master"
	p.volume_db = linear_to_db(maxf(0.0001, volume_linear))
	p.stream = _load_audio_stream_from_base(base_path_without_ext, looped)
	add_child(p)
	return p

func _load_audio_stream_from_base(base_path_without_ext: String, loop_stream: bool) -> AudioStream:
	var stream: AudioStream = _resolve_audio_stream(base_path_without_ext)
	_apply_stream_loop(stream, loop_stream)
	return stream

func _resolve_audio_stream(base_path_without_ext: String) -> AudioStream:
	var exts: PackedStringArray = PackedStringArray([".wav", ".mp3", ".ogg"])
	for i: int in range(exts.size()):
		var path: String = base_path_without_ext + str(exts[i])
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			return stream
		if not _warned_missing.has(path):
			_warned_missing[path] = true
			push_warning("Audio failed to load: %s" % path)
	if not _warned_missing.has(base_path_without_ext):
		_warned_missing[base_path_without_ext] = true
		push_warning("Audio missing (no .wav/.mp3/.ogg): %s" % base_path_without_ext)
	return null

func _apply_stream_loop(stream: AudioStream, looped: bool) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looped
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looped
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED

func _play_if_ready(p: AudioStreamPlayer, pitch_scale: float = 1.0) -> void:
	if p == null or p.stream == null:
		return
	p.pitch_scale = pitch_scale
	p.play()

## Pauses the whole scene tree until `start_song` finishes (this node stays `PROCESS_MODE_ALWAYS`).
## Returns false if no `start_song` file — caller should start BGM immediately.
func try_begin_start_song_blocking(tree: SceneTree) -> bool:
	if tree == null:
		return false
	if _start_song_player == null or _start_song_player.stream == null:
		return false
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree.paused = true
	_start_song_player.play()
	return true

func _on_start_song_finished() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	var scene_tree: SceneTree = get_tree()
	if scene_tree != null and scene_tree.paused:
		scene_tree.paused = false
	start_song_finished.emit()

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
	if bool(model.get("sfx_power_pellet")) or bool(model.get("sfx_pellet")):
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

func play_pac_death() -> bool:
	if _pac_death_player == null or _pac_death_player.stream == null:
		return false
	_pac_death_player.play()
	return true

func maybe_play_low_time_warning(_prev_sec: int, _next_sec: int) -> void:
	pass

func update_ghost_ambience(model: RefCounted, dt: float) -> void:
	if model == null:
		_fade_out_ghost_alive_global(dt)
		_fade_out_ghost_incap_loops(dt)
		_apply_fear_global_gain(dt, false)
		return
	if _read_variant_bool(model, "is_game_over", false):
		_fade_out_ghost_alive_global(dt)
		_fade_out_ghost_incap_loops(dt)
		_apply_fear_global_gain(dt, false)
		return
	var ghosts_v: Variant = model.get("ghosts")
	if typeof(ghosts_v) != TYPE_ARRAY:
		_fade_out_ghost_alive_global(dt)
		_fade_out_ghost_incap_loops(dt)
		_apply_fear_global_gain(dt, false)
		return
	var ghosts: Array = ghosts_v as Array
	var global_fear_ms: float = _read_variant_float(model, "fear_ms", 0.0)
	if global_fear_ms > 0.0:
		_apply_fear_global_gain(dt, true)
		_fade_out_ghost_alive_global(dt)
		_fade_out_ghost_incap_loops(dt)
		return

	_apply_fear_global_gain(dt, false)
	var pac_pos: Vector2 = _variant_to_vec2(model.get("pac_pos"), Vector2.ZERO)
	var count: int = min(ghosts.size(), _ghost_incap_loop_players.size())

	var alive_count: int = 0
	var k_best_alive: float = 0.0
	for ig: int in range(ghosts.size()):
		var g_alive: Variant = ghosts[ig]
		if _read_variant_bool(g_alive, "is_incapacitated", false):
			continue
		alive_count += 1
		var gpos_a: Vector2 = _read_variant_vec2(g_alive, "pos", Vector2.ZERO)
		var d_a: float = gpos_a.distance_to(pac_pos)
		var k_a: float = 1.0 - clampf(d_a / GHOST_HEAR_RADIUS_TILES, 0.0, 1.0)
		k_a = pow(k_a, GHOST_DISTANCE_ATTENUATION_EXP)
		k_best_alive = maxf(k_best_alive, k_a)

	var target_alive_gain: float = 0.0
	if alive_count > 0:
		var count_mul: float = 1.0 + GHOST_ALIVE_PER_EXTRA_GHOST * float(alive_count - 1)
		target_alive_gain = minf(
			GHOST_ALIVE_GLOBAL_GAIN_CAP,
			GHOST_BASE_VOLUME_ALIVE * k_best_alive * count_mul
		)
	_apply_ghost_alive_global_gain(dt, target_alive_gain)

	var incap_stream: AudioStream = _ghost_state_streams.get("incapacitated") as AudioStream
	for i: int in range(count):
		var g_v: Variant = ghosts[i]
		var player: AudioStreamPlayer = _ghost_incap_loop_players[i]
		if not _read_variant_bool(g_v, "is_incapacitated", false):
			var fade_g: float = lerpf(_ghost_incap_loop_gain_linear[i], 0.0, clampf(dt * GHOST_VOLUME_SMOOTH_PER_SEC, 0.0, 1.0))
			_ghost_incap_loop_gain_linear[i] = fade_g
			if fade_g <= 0.001:
				player.stop()
				_ghost_incap_loop_gain_linear[i] = 0.0
			else:
				player.volume_db = linear_to_db(maxf(0.0001, fade_g))
			continue

		if player.stream != incap_stream:
			player.stop()
			player.stream = incap_stream
		if player.stream == null:
			player.stop()
			_ghost_incap_loop_gain_linear[i] = 0.0
			continue

		var gpos: Vector2 = _read_variant_vec2(g_v, "pos", Vector2.ZERO)
		var d: float = gpos.distance_to(pac_pos)
		var k: float = 1.0 - clampf(d / GHOST_HEAR_RADIUS_TILES, 0.0, 1.0)
		k = pow(k, GHOST_DISTANCE_ATTENUATION_EXP)
		var target_gain: float = GHOST_BASE_VOLUME_INCAP * k
		var cur_gain: float = _ghost_incap_loop_gain_linear[i]
		var t: float = clampf(dt * GHOST_VOLUME_SMOOTH_PER_SEC, 0.0, 1.0)
		cur_gain = lerpf(cur_gain, target_gain, t)
		_ghost_incap_loop_gain_linear[i] = cur_gain
		if cur_gain <= 0.001:
			player.stop()
			continue
		player.volume_db = linear_to_db(maxf(0.0001, cur_gain))
		if not player.playing:
			player.play()

	for j: int in range(count, _ghost_incap_loop_players.size()):
		var pj: AudioStreamPlayer = _ghost_incap_loop_players[j]
		pj.stop()
		_ghost_incap_loop_gain_linear[j] = 0.0

func _apply_ghost_alive_global_gain(dt: float, target_linear: float) -> void:
	if _ghost_alive_global_player == null or _ghost_alive_global_player.stream == null:
		return
	var t: float = clampf(dt * GHOST_VOLUME_SMOOTH_PER_SEC, 0.0, 1.0)
	_ghost_alive_global_gain_linear = lerpf(_ghost_alive_global_gain_linear, target_linear, t)
	if _ghost_alive_global_gain_linear <= 0.001:
		_ghost_alive_global_player.stop()
		return
	_ghost_alive_global_player.volume_db = linear_to_db(maxf(0.0001, _ghost_alive_global_gain_linear))
	if not _ghost_alive_global_player.playing:
		_ghost_alive_global_player.play()

func _fade_out_ghost_alive_global(dt: float) -> void:
	_apply_ghost_alive_global_gain(dt, 0.0)

func _init_ghost_incap_loop_players(count: int) -> void:
	_ghost_incap_loop_players.clear()
	_ghost_incap_loop_gain_linear.clear()
	for i: int in range(count):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "GhostIncapLoop%d" % i
		p.bus = "Master"
		p.volume_db = linear_to_db(0.0001)
		add_child(p)
		_ghost_incap_loop_players.append(p)
		_ghost_incap_loop_gain_linear.append(0.0)

func _apply_fear_global_gain(dt: float, active: bool) -> void:
	if _fear_global_player == null or _fear_global_player.stream == null:
		return
	var target: float = GHOST_FEAR_GLOBAL_VOLUME_LINEAR if active else 0.0
	var t: float = clampf(dt * GHOST_VOLUME_SMOOTH_PER_SEC, 0.0, 1.0)
	_fear_global_gain_linear = lerpf(_fear_global_gain_linear, target, t)
	if _fear_global_gain_linear <= 0.001:
		_fear_global_player.stop()
		return
	_fear_global_player.volume_db = linear_to_db(maxf(0.0001, _fear_global_gain_linear))
	if not _fear_global_player.playing:
		_fear_global_player.play()

func _fade_out_ghost_incap_loops(dt: float) -> void:
	for i: int in range(_ghost_incap_loop_players.size()):
		var p: AudioStreamPlayer = _ghost_incap_loop_players[i]
		_ghost_incap_loop_gain_linear[i] = lerpf(_ghost_incap_loop_gain_linear[i], 0.0, clampf(dt * GHOST_VOLUME_SMOOTH_PER_SEC, 0.0, 1.0))
		if _ghost_incap_loop_gain_linear[i] <= 0.001:
			p.stop()
			_ghost_incap_loop_gain_linear[i] = 0.0
			continue
		p.volume_db = linear_to_db(maxf(0.0001, _ghost_incap_loop_gain_linear[i]))

func _variant_to_vec2(v: Variant, default_v: Vector2) -> Vector2:
	if typeof(v) == TYPE_VECTOR2:
		return v as Vector2
	if typeof(v) == TYPE_VECTOR2I:
		var vi: Vector2i = v as Vector2i
		return Vector2(float(vi.x), float(vi.y))
	return default_v

func _read_variant_bool(host: Variant, key: String, default_v: bool) -> bool:
	if typeof(host) == TYPE_DICTIONARY:
		var d: Dictionary = host as Dictionary
		if d.has(key):
			return bool(d.get(key))
		return default_v
	var o: Object = host as Object
	if o != null:
		return bool(o.get(key))
	return default_v

func _read_variant_float(host: Variant, key: String, default_v: float) -> float:
	var vv: Variant = null
	if typeof(host) == TYPE_DICTIONARY:
		var d: Dictionary = host as Dictionary
		if not d.has(key):
			return default_v
		vv = d.get(key)
	else:
		var o: Object = host as Object
		if o == null:
			return default_v
		vv = o.get(key)
	if typeof(vv) == TYPE_INT:
		return float(int(vv))
	if typeof(vv) == TYPE_FLOAT:
		return float(vv)
	return default_v

func _read_variant_vec2(host: Variant, key: String, default_v: Vector2) -> Vector2:
	var vv: Variant = null
	if typeof(host) == TYPE_DICTIONARY:
		var d: Dictionary = host as Dictionary
		if not d.has(key):
			return default_v
		vv = d.get(key)
	else:
		var o: Object = host as Object
		if o == null:
			return default_v
		vv = o.get(key)
	return _variant_to_vec2(vv, default_v)
