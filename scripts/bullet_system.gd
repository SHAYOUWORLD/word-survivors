extends Node2D
## Player's auto-firing bullet system.
## Holds 4 Japanese "bullet words" — one per POS (noun/verb/adjective/adverb).
## The 4 slots are organized into 2 groups of 2:
##   group 0 = slots[0..1]  (noun + verb)
##   group 1 = slots[2..3]  (adjective + adverb)
## TAB toggles the active group. Each volley fires one bullet for every word
## in the active group (2 bullets per volley). A bullet can only kill an enemy
## whose english id matches the bullet's word id (see bullet.gd).

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

const SLOT_COUNT := 4
const GROUP_SIZE := 2
const FIRE_INTERVAL := 0.45
const BULLET_SPEED := 320.0
const BULLET_LIFETIME := 2.0
const SPREAD_ANGLE := 0.18  # radians between adjacent bullets in a volley

# Which POS occupies each slot index. Also defines the grouping.
const SLOT_POS := ["noun", "verb", "adjective", "adverb"]

var slots: Array = []   # Array[Dictionary] — length SLOT_COUNT when loaded
var active_group: int = 0  # 0 = [noun, verb], 1 = [adjective, adverb]
var _cooldown: float = 0.0

var player: Node2D = null

signal slots_changed
signal active_changed
signal fired

func _ready() -> void:
	set_process_unhandled_input(true)

func attach_to_player(p: Node2D) -> void:
	player = p

## Replace all 4 held words. Called at run start.
func set_slots(words: Array) -> void:
	slots = []
	for w in words:
		slots.append(w)
	active_group = 0
	slots_changed.emit()
	active_changed.emit()

## Replace a single slot by index. Used when a quiz answer rotates only the
## matched word rather than the entire loadout.
func set_slot(idx: int, word: Dictionary) -> void:
	if idx < 0 or idx >= slots.size():
		return
	slots[idx] = word
	slots_changed.emit()

func get_slot_ids() -> Array:
	var out: Array = []
	for w in slots:
		out.append(w.get("id", ""))
	return out

## Returns the 2 words in the currently active group.
func get_active_words() -> Array:
	if slots.size() < SLOT_COUNT:
		return []
	var start: int = active_group * GROUP_SIZE
	return [slots[start], slots[start + 1]]

## Returns the slot index (0..3) whose pos matches the given POS name,
## or -1 if no slot holds that POS.
func find_slot_by_pos(pos: String) -> int:
	for i in slots.size():
		var w: Dictionary = slots[i]
		if w.get("pos", "") == pos:
			return i
	return -1

func toggle_active() -> void:
	if slots.size() < SLOT_COUNT:
		return
	active_group = 1 - active_group
	active_changed.emit()
	AudioManager.play_sfx("button", 0.0, -10.0)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if event.is_action_pressed("toggle_bullet"):
		toggle_active()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if slots.is_empty() or player == null:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire_volley()

func _fire_volley() -> void:
	var words: Array = get_active_words()
	if words.is_empty():
		return
	var target: Node2D = _nearest_enemy()
	var base_dir: Vector2
	if target == null:
		base_dir = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		base_dir = (target.global_position - player.global_position).normalized()

	var count: int = words.size()
	for i in count:
		var offset: float = SPREAD_ANGLE * (float(i) - (float(count) - 1.0) * 0.5)
		var dir: Vector2 = base_dir.rotated(offset)
		var b = BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = player.global_position
		b.setup(words[i], dir * BULLET_SPEED, BULLET_LIFETIME)
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
