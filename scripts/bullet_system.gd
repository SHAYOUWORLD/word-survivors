extends Node2D
## Player's auto-firing bullet system — pocv5 rewrite.
## Holds exactly 2 Japanese "bullet words". TAB switches which one is active;
## only the active word fires. Each volley shoots BULLETS_PER_SHOT bullets of
## the active word toward the nearest enemy. A bullet can only kill an enemy
## whose english id matches the bullet's word id (see bullet.gd).

const BULLET_SCENE := preload("res://scenes/bullet.tscn")

const SLOT_COUNT := 2
const BULLETS_PER_SHOT := 2
const FIRE_INTERVAL := 0.45
const BULLET_SPEED := 320.0
const BULLET_LIFETIME := 2.0
const SPREAD_ANGLE := 0.18  # radians between adjacent bullets in a volley

var slots: Array = []   # Array[Dictionary] — length SLOT_COUNT when loaded
var active_idx: int = 0
var _cooldown: float = 0.0

var player: Node2D = null

signal slots_changed
signal active_changed
signal fired

func _ready() -> void:
	set_process_unhandled_input(true)

func attach_to_player(p: Node2D) -> void:
	player = p

## Replace the 2 held words. Called at run start and after each correct quiz.
func set_slots(word_a: Dictionary, word_b: Dictionary) -> void:
	slots = [word_a, word_b]
	active_idx = 0
	slots_changed.emit()
	active_changed.emit()

func get_slot_ids() -> Array:
	var out: Array = []
	for w in slots:
		out.append(w.get("id", ""))
	return out

func get_active_word() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[active_idx]

func toggle_active() -> void:
	if slots.size() < 2:
		return
	active_idx = (active_idx + 1) % slots.size()
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
	var word: Dictionary = get_active_word()
	if word.is_empty():
		return
	var target: Node2D = _nearest_enemy()
	var base_dir: Vector2
	if target == null:
		base_dir = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		base_dir = (target.global_position - player.global_position).normalized()

	for i in BULLETS_PER_SHOT:
		var offset: float = SPREAD_ANGLE * (float(i) - (float(BULLETS_PER_SHOT) - 1.0) * 0.5)
		var dir: Vector2 = base_dir.rotated(offset)
		var b = BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = player.global_position
		b.setup(word, dir * BULLET_SPEED, BULLET_LIFETIME)
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
