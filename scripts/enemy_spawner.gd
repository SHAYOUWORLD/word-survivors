extends Node2D
## Spawns enemies whose english word matches one of the 4 currently loaded
## bullet words on the player. Each bullet slot is a different POS
## (noun/verb/adjective/adverb), so the enemy pool is always exactly one word
## per POS. To keep colors visually distinct on screen, at most one enemy per
## POS color is alive at any time — i.e. total live enemies cap at 4.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

# Hard cap = one enemy per POS color, so never more than 4 live at once.
const MAX_PER_POS := 1

# Difficulty curve: shorter interval = faster respawn after a kill.
const CURVE := [
	{"t":   0.0, "interval": 0.60, "speed": 55.0},
	{"t":  20.0, "interval": 0.45, "speed": 60.0},
	{"t":  60.0, "interval": 0.35, "speed": 65.0},
	{"t": 120.0, "interval": 0.25, "speed": 72.0},
	{"t": 240.0, "interval": 0.18, "speed": 80.0},
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
		_try_spawn(float(params.speed))

func _current_curve() -> Dictionary:
	var current: Dictionary = CURVE[0]
	for entry in CURVE:
		if GameManager.run_time >= float(entry.t):
			current = entry
	return current

## Spawns one enemy, picking a POS that currently has fewer than MAX_PER_POS
## live enemies. If every POS is already full, skip this tick.
func _try_spawn(speed: float) -> void:
	var bs: Node = _get_bullet_system()
	if bs == null or bs.slots.size() < bs.SLOT_COUNT:
		return

	var live_by_pos: Dictionary = _count_live_by_pos()
	var candidates: Array = []
	for w in bs.slots:
		var pos_name: String = w.get("pos", "")
		if int(live_by_pos.get(pos_name, 0)) < MAX_PER_POS:
			candidates.append(w)
	if candidates.is_empty():
		return

	var word: Dictionary = candidates[randi() % candidates.size()]
	var spawn_pos: Vector2 = _random_offscreen_position()
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(word, speed)
	add_child(enemy)
	enemy.global_position = spawn_pos

func _count_live_by_pos() -> Dictionary:
	var counts: Dictionary = {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var val = e.get("word_data")
		if val is Dictionary:
			var pos_name: String = (val as Dictionary).get("pos", "")
			counts[pos_name] = int(counts.get(pos_name, 0)) + 1
	return counts

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
