extends Node2D
## Player's auto-firing bullet system. Holds up to MAX_SLOTS English words;
## fires them cyclically at FIRE_INTERVAL toward the nearest enemy.

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

const MAX_SLOTS := 12
const FIRE_INTERVAL := 0.3
const BULLET_SPEED := 300.0
const BULLET_LIFETIME := 2.0

var held_words: Array = []   # Array[Dictionary]
var _current_idx: int = 0
var _cooldown: float = 0.0

var player: Node2D = null

signal slots_changed
signal fired

func attach_to_player(p: Node2D) -> void:
	player = p

func add_word(word: Dictionary) -> bool:
	if word.is_empty():
		return false
	if held_words.size() >= MAX_SLOTS:
		return false
	if has_word(word.get("id", "")):
		return false
	held_words.append(word)
	slots_changed.emit()
	return true

func has_word(id: String) -> bool:
	for w in held_words:
		if w.get("id", "") == id:
			return true
	return false

func get_held_word_ids() -> Array:
	var out: Array = []
	for w in held_words:
		out.append(w.get("id", ""))
	return out

## Returns up to `count` of the next words that will be fired, in rotation
## order starting from the current index. Used by the HUD bullet queue.
func get_next_words(count: int) -> Array:
	var out: Array = []
	if held_words.is_empty():
		return out
	var n: int = held_words.size()
	var take: int = mini(count, n)
	for i in range(take):
		var idx: int = (_current_idx + i) % n
		out.append(held_words[idx])
	return out

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if held_words.is_empty() or player == null:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire_next()

func _fire_next() -> void:
	if held_words.is_empty():
		return
	var word: Dictionary = held_words[_current_idx % held_words.size()]
	_current_idx = (_current_idx + 1) % held_words.size()

	var target: Node2D = _nearest_enemy()
	var dir: Vector2
	if target == null:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		dir = (target.global_position - player.global_position).normalized()

	# Apply per-POS speed upgrade (each point = +25% velocity).
	var word_id: String = word.get("id", "")
	var word_pos: String = word.get("pos", "")
	var speed: float = BULLET_SPEED * PosUpgrades.velocity_multiplier(word_pos)

	var b = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = player.global_position
	b.setup(word, dir * speed, BULLET_LIFETIME)

	LearningTracker.record_fire(word_id)
	fired.emit()

func _nearest_enemy() -> Node2D:
	if player == null:
		return null
	var best: Node2D = null
	var best_d: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var d: float = en.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best
