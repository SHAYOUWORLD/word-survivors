extends Node2D
## Spawns enemies off-screen, with 70% chance of staying in the same POS
## group (and near the last spawn position) to create natural POS clusters.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const MAX_ENEMIES := 50
const SAME_GROUP_CHANCE := 0.7
const GROUP_CLUSTER_RADIUS := 80.0

# Difficulty curve: {t_start, interval, speed}. The last entry is used for
# t >= its t_start.
const CURVE := [
	{"t": 0.0,   "interval": 1.5, "speed": 50.0},
	{"t": 60.0,  "interval": 1.0, "speed": 60.0},
	{"t": 150.0, "interval": 0.7, "speed": 70.0},
	{"t": 240.0, "interval": 0.4, "speed": 80.0},
]

var _player: Node2D = null
var _spawn_cooldown: float = 0.0
var _last_pos_group: String = ""
var _last_spawn_pos: Vector2 = Vector2.ZERO

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
	if _spawn_cooldown <= 0.0 and _enemy_count() < MAX_ENEMIES:
		_spawn_cooldown = float(params.interval)
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
	# Decide POS group.
	var use_same := (_last_pos_group != "") and (randf() < SAME_GROUP_CHANCE)
	var pos_group: String
	if use_same:
		pos_group = _last_pos_group
	else:
		pos_group = WordDatabase.all_pos_list().pick_random()

	var word: Dictionary = WordDatabase.get_random_word_by_pos(pos_group)
	if word.is_empty():
		return

	var spawn_pos: Vector2
	if use_same:
		spawn_pos = _last_spawn_pos + Vector2(
			randf_range(-GROUP_CLUSTER_RADIUS, GROUP_CLUSTER_RADIUS),
			randf_range(-GROUP_CLUSTER_RADIUS, GROUP_CLUSTER_RADIUS)
		)
	else:
		spawn_pos = _random_offscreen_position()

	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(word, speed)
	add_child(enemy)
	enemy.global_position = spawn_pos

	_last_spawn_pos = spawn_pos
	_last_pos_group = pos_group

func _random_offscreen_position() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(820.0, 1100.0)
	return _player.global_position + Vector2.from_angle(angle) * dist
