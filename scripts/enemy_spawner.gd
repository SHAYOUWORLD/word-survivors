extends Node2D
## pocv5: spawns enemies whose english word matches one of the 2 currently
## loaded bullet words on the player. This guarantees every enemy is killable
## with the right bullet — TAB is how the player chooses which one to fire.
## A small fraction (NOISE_RATIO) of spawns use a random word from the full
## database so the screen isn't totally homogeneous.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const MAX_ENEMIES := 120
const NOISE_RATIO := 0.0  # 0.0 = only-matching spawns. Bump for chaos.

# Difficulty curve: each entry spawns `batch` enemies every `interval` seconds.
const CURVE := [
	{"t":   0.0, "interval": 0.60, "speed": 55.0, "batch": 1},
	{"t":  20.0, "interval": 0.45, "speed": 60.0, "batch": 2},
	{"t":  60.0, "interval": 0.35, "speed": 65.0, "batch": 2},
	{"t": 120.0, "interval": 0.25, "speed": 72.0, "batch": 3},
	{"t": 240.0, "interval": 0.18, "speed": 80.0, "batch": 4},
]

var _player: Node2D = null
var _spawn_cooldown: float = 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var params: Dictionary = _current_curve()
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_cooldown = float(params.interval)
		var batch: int = int(params.get("batch", 1))
		for i in batch:
			if _enemy_count() >= MAX_ENEMIES:
				break
			_spawn_one(float(params.speed))

func _current_curve() -> Dictionary:
	var current: Dictionary = CURVE[0]
	for entry in CURVE:
		if GameManager.run_time >= float(entry.t):
			current = entry
	return current

func _enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _spawn_one(speed: float) -> void:
	var word: Dictionary = _pick_word()
	if word.is_empty():
		return
	var spawn_pos: Vector2 = _random_offscreen_position()
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(word, speed)
	add_child(enemy)
	enemy.global_position = spawn_pos

func _pick_word() -> Dictionary:
	# Prefer a word currently loaded in the player's bullet slots.
	var bs: Node = _get_bullet_system()
	var slot_words: Array = []
	if bs != null:
		slot_words = bs.slots
	if not slot_words.is_empty() and randf() >= NOISE_RATIO:
		return slot_words[randi() % slot_words.size()]
	return WordDatabase.get_random_word()

func _get_bullet_system() -> Node:
	if _player == null:
		return null
	if not _player.has_node("BulletSystem"):
		return null
	return _player.get_node("BulletSystem")

func _random_offscreen_position() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(820.0, 1100.0)
	return _player.global_position + Vector2.from_angle(angle) * dist
