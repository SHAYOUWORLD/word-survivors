extends Node
## BGM crossfader + pooled SFX player. All audio lives here so scenes just
## call AudioManager.play_sfx("hit") / play_bgm("gameplay").

const BGM_BUS := "Master"
const SFX_BUS := "Master"

const BGM_FILES := {
	"title":    "res://assets/audio/bgm/title.ogg",
	"gameplay": "res://assets/audio/bgm/stage_05_sengoku.ogg",
	"tutorial": "res://assets/audio/bgm/stage_00_tutorial.ogg",
}

# Logical SFX names → file paths. Multiple names can share a file.
const SFX_FILES := {
	"hit":        "res://assets/audio/sfx/attack.wav",
	"hit_heavy":  "res://assets/audio/sfx/special_hit.wav",
	"damage":     "res://assets/audio/sfx/damage.wav",
	"heal":       "res://assets/audio/sfx/heal.wav",
	"button":     "res://assets/audio/sfx/button.wav",
	"buff":       "res://assets/audio/sfx/buff.wav",
	"levelup":    "res://assets/audio/sfx/card_play.wav",
	"choice":     "res://assets/audio/sfx/card_draw.wav",
	"pickup":     "res://assets/audio/sfx/gold_display.wav",
	"evolve":     "res://assets/audio/sfx/chronicle_clear_cheer.wav",
	"synergy":    "res://assets/audio/sfx/quiz_correct.wav",
	"game_over":  "res://assets/audio/sfx/game_over_shock.wav",
	"win":        "res://assets/audio/sfx/win.wav",
	"lose":       "res://assets/audio/sfx/lose.wav",
	"boom":       "res://assets/audio/sfx/taiko_dodon.wav",
	"incoming":   "res://assets/audio/sfx/heavy_incoming_hit.wav",
}

const SFX_POOL_SIZE := 10

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _current_bgm_key: String = ""

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _bgm_cache: Dictionary = {}

var bgm_volume_db: float = -14.0
var sfx_volume_db: float = -12.0
## Pronunciation voice sits much louder than SFX so the word the player is
## learning cuts cleanly through the soundscape.
var voice_volume_db: float = 0.0

func _ready() -> void:
	_bgm_a = _make_bgm_player("BGM_A")
	_bgm_b = _make_bgm_player("BGM_B")
	_bgm_active = _bgm_a
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_players.append(p)

func _make_bgm_player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = BGM_BUS
	p.volume_db = -80.0
	add_child(p)
	return p

# --- BGM ---

func play_bgm(key: String, fade: float = 0.8) -> void:
	if key == _current_bgm_key and _bgm_active.playing:
		return
	if not BGM_FILES.has(key):
		push_warning("AudioManager: unknown BGM '%s'" % key)
		return
	var stream: AudioStream = _load_bgm(key)
	if stream == null:
		return
	var next_player := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next_player, "volume_db", bgm_volume_db, fade)
	tw.tween_property(_bgm_active, "volume_db", -80.0, fade)
	tw.chain().tween_callback(_bgm_active.stop)
	_bgm_active = next_player
	_current_bgm_key = key

func stop_bgm(fade: float = 0.5) -> void:
	if _bgm_active and _bgm_active.playing:
		var tw := create_tween()
		tw.tween_property(_bgm_active, "volume_db", -80.0, fade)
		tw.tween_callback(_bgm_active.stop)
	_current_bgm_key = ""

func _load_bgm(key: String) -> AudioStream:
	if _bgm_cache.has(key):
		return _bgm_cache[key]
	var path: String = BGM_FILES[key]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM file missing %s" % path)
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_bgm_cache[key] = s
	return s

# --- SFX ---

func play_sfx(key: String, pitch_variance: float = 0.0, volume_offset: float = 0.0) -> void:
	var stream: AudioStream = _load_sfx(key)
	if stream == null:
		return
	var player := _get_free_sfx_player()
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset
	if pitch_variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	else:
		player.pitch_scale = 1.0
	player.play()

func _load_sfx(key: String) -> AudioStream:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	if not SFX_FILES.has(key):
		push_warning("AudioManager: unknown SFX '%s'" % key)
		return null
	var path: String = SFX_FILES[key]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX file missing %s" % path)
		return null
	var s: AudioStream = load(path)
	_sfx_cache[key] = s
	return s

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]

# --- Voice (per-word pronunciation) ---

const VOICE_DIR := "res://assets/audio/voice/"
var _voice_cache: Dictionary = {}

## Plays the pronunciation file for the given word_id if one exists at
## res://assets/audio/voice/<word_id>.ogg (or .wav). Silently no-ops when
## the file is missing — voice assets are optional in the PoC.
func play_voice(word_id: String, volume_offset: float = 0.0) -> void:
	if word_id == "":
		return
	var stream: AudioStream = _load_voice(word_id)
	if stream == null:
		return
	var player := _get_free_sfx_player()
	player.stream = stream
	# Voice uses its own (much louder) volume knob so the pronunciation sits
	# well above SFX and BGM.
	player.volume_db = voice_volume_db + volume_offset
	player.pitch_scale = 1.0
	player.play()

func _load_voice(word_id: String) -> AudioStream:
	if _voice_cache.has(word_id):
		return _voice_cache[word_id]
	# Prefer real recordings (.ogg/.mp3 from dictionary sources) over the
	# SAPI fallback (.wav).
	for ext in [".ogg", ".mp3", ".wav"]:
		var path: String = VOICE_DIR + word_id + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_voice_cache[word_id] = s
			return s
	# Cache a null so we stop retrying every crit.
	_voice_cache[word_id] = null
	return null
