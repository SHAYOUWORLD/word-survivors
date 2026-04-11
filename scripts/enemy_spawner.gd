extends Node2D
## Spawns enemies off-screen, with 70% chance of staying in the same POS
## group (and near the last spawn position) to create natural POS clusters.
##
## pocv4 additions:
## - Words that are FULLY_MASTERED or MASTERED_SCHEDULED are filtered out of
##   the regular pool (via MasteryTracker).
## - Each frame, the spawner asks MasteryTracker for any due reviews and, if
##   so, injects a single "review enemy" for that word (bypasses cooldown
##   and max-enemy cap — reviews always go through).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const MAX_ENEMIES := 120
const SAME_GROUP_CHANCE := 0.75
const GROUP_CLUSTER_RADIUS := 110.0

# Difficulty curve: each entry spawns `batch` enemies every `interval` seconds.
# Warm-up first, then aggressive ramp so pocv4 feels like a proper
# Survivors swarm without blowing the player up in the first 5 seconds.
const CURVE := [
	{"t":   0.0, "interval": 0.50, "speed": 55.0, "batch": 1},
	{"t":  15.0, "interval": 0.40, "speed": 60.0, "batch": 2},
	{"t":  45.0, "interval": 0.30, "speed": 65.0, "batch": 3},
	{"t": 100.0, "interval": 0.22, "speed": 72.0, "batch": 4},
	{"t": 180.0, "interval": 0.15, "speed": 80.0, "batch": 5},
	{"t": 280.0, "interval": 0.10, "speed": 88.0, "batch": 6},
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

	# Reviews first — always honored, regardless of cooldown or cap.
	_maybe_spawn_review()

	var params: Dictionary = _current_curve()
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_cooldown = float(params.interval)
		var batch: int = int(params.get("batch", 1))
		for i in batch:
			if _enemy_count() >= MAX_ENEMIES:
				break
			_spawn_one(float(params.speed))

func _maybe_spawn_review() -> void:
	var due_id: String = MasteryTracker.pop_due_review(GameManager.run_time)
	if due_id == "":
		return
	var word: Dictionary = WordDatabase.get_word(due_id)
	if word.is_empty():
		return
	# Speed matches current curve so it's not a free kill.
	var speed: float = float(_current_curve().speed)
	var spawn_pos: Vector2 = _random_offscreen_position()
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(word, speed, true)  # review = true
	add_child(enemy)
	enemy.global_position = spawn_pos

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

	var word: Dictionary = _pick_phase_a_word(pos_group)
	if word.is_empty():
		# No PHASE_A words left in this POS — try any POS.
		word = _pick_phase_a_word("")
	if word.is_empty():
		# Every word is mastered or in-progress toward mastery — nothing to spawn.
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
	enemy.setup(word, speed, false)
	add_child(enemy)
	enemy.global_position = spawn_pos

	_last_spawn_pos = spawn_pos
	_last_pos_group = word.get("pos", "")

## Pick a random word in PHASE_A. If pos_filter is empty, search all POSes.
func _pick_phase_a_word(pos_filter: String) -> Dictionary:
	var pool: Array = []
	if pos_filter == "":
		pool = WordDatabase.all_words
	else:
		pool = WordDatabase.words_by_pos.get(pos_filter, [])
	var eligible: Array = []
	for w in pool:
		if MasteryTracker.get_state(w.get("id", "")) == MasteryTracker.State.PHASE_A:
			eligible.append(w)
	if eligible.is_empty():
		return {}
	return eligible[randi() % eligible.size()]

func _random_offscreen_position() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(820.0, 1100.0)
	return _player.global_position + Vector2.from_angle(angle) * dist
