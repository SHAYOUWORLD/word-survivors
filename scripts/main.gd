extends Node2D
## Main gameplay scene for pocv5.
## - Wires player, spawner, camera, HUD, critical callout, quiz panel.
## - Seeds 2 Japanese "bullet words" into the player's BulletSystem.
## - Receives bullet-match events via on_bullet_match() and plays big feedback.
## - Listens for GameManager.quiz_threshold_reached (every 10 kills) and
##   opens the 4-choice quiz. A correct answer rotates the bullet system to
##   a fresh pair of Japanese words.

const FxSpawner := preload("res://scripts/fx_spawner.gd")

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var critical_callout: CanvasLayer = $CriticalCallout
@onready var quiz_panel: CanvasLayer = $QuizPanel
@onready var grid: Node2D = $Grid

var _shake_amount: float = 0.0
var _shake_decay: float = 24.0

func _ready() -> void:
	randomize()
	GameManager.start_run()

	var bs: Node = player.get_node("BulletSystem")
	bs.attach_to_player(player)
	_rotate_bullet_slots(bs, [])

	hud.bind_player(player)

	player.died.connect(_on_player_died)
	player.hit_taken.connect(_on_player_hit)
	quiz_panel.answered.connect(_on_quiz_answered)
	GameManager.quiz_threshold_reached.connect(_on_quiz_threshold_reached)

	AudioManager.play_bgm("gameplay", 0.6)

func _process(delta: float) -> void:
	if player and is_instance_valid(player):
		var offset := Vector2.ZERO
		if _shake_amount > 0.01:
			offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
			_shake_amount = max(0.0, _shake_amount - _shake_decay * delta)
		camera.global_position = player.global_position + offset

	if GameManager.state == GameManager.State.GAMEOVER:
		_goto_result()

func shake(amount: float) -> void:
	_shake_amount = max(_shake_amount, amount)

# Called by bullet.gd on every successful match kill.
func on_bullet_match(bullet_word: Dictionary, enemy_word: Dictionary, enemy_pos: Vector2) -> void:
	var color: Color = WordDatabase.get_pos_color(enemy_word.get("pos", "noun"))
	critical_callout.show_pair(
		enemy_word.get("english", ""),
		bullet_word.get("japanese", ""),
		color,
		enemy_word.get("id", "")
	)
	FxSpawner.spawn_mega_burst(self, enemy_pos, color)
	FxSpawner.spawn_sparkles(self, enemy_pos, Color(1, 0.95, 0.6, 1))
	shake(10.0)
	_hitstop(0.04)
	AudioManager.play_sfx("boom", 0.0, -2.0)
	AudioManager.play_sfx("hit_heavy", 0.0, -4.0)

func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.02
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_player_hit() -> void:
	shake(10.0)

func _on_player_died() -> void:
	GameManager.trigger_game_over()

func _goto_result() -> void:
	set_process(false)
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")

# ---------- pocv5 quiz flow ----------

func _on_quiz_threshold_reached(word: Dictionary) -> void:
	GameManager.set_state(GameManager.State.QUIZ)
	quiz_panel.show_quiz(word, false)

func _on_quiz_answered(word_id: String, correct: bool, _is_review: bool) -> void:
	var word: Dictionary = WordDatabase.get_word(word_id)
	GameManager.set_state(GameManager.State.PLAYING)
	if correct:
		_play_big_explosion(word)
		var bs: Node = player.get_node("BulletSystem")
		_rotate_bullet_slots(bs, bs.get_slot_ids())
	else:
		shake(8.0)
		AudioManager.play_sfx("damage")

## Picks 2 fresh Japanese words and loads them into the bullet system.
## `exclude_ids` lets us avoid immediately re-picking the same two.
func _rotate_bullet_slots(bs: Node, exclude_ids: Array) -> void:
	var pool: Array = []
	for w in WordDatabase.all_words:
		var wid: String = w.get("id", "")
		if wid == "" or exclude_ids.has(wid):
			continue
		pool.append(w)
	if pool.size() < 2:
		# Fallback: allow re-picking if the database is tiny.
		pool = WordDatabase.all_words.duplicate()
	pool.shuffle()
	if pool.size() >= 2:
		bs.set_slots(pool[0], pool[1])
	elif pool.size() == 1:
		bs.set_slots(pool[0], pool[0])

## Screen-clearing burst played on correct quiz answer.
func _play_big_explosion(word: Dictionary) -> void:
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	color.a = 1.0

	if player and is_instance_valid(player):
		FxSpawner.spawn_mega_burst(self, player.global_position, color)
		FxSpawner.spawn_sparkles(self, player.global_position, Color(1, 0.95, 0.6, 1))

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var val = en.get("word_data")
		var en_pos_name: String = "noun"
		if val is Dictionary:
			en_pos_name = (val as Dictionary).get("pos", "noun")
		var en_color: Color = WordDatabase.get_pos_color(en_pos_name)
		en_color.a = 1.0
		FxSpawner.spawn_burst(self, en.global_position, en_color, 14, 1.0)
		en.queue_free()

	shake(22.0)
	_hitstop(0.08)

	AudioManager.play_sfx("boom", 0.0, 0.0)
	AudioManager.play_sfx("hit_heavy", 0.0, -2.0)
	AudioManager.play_sfx("synergy", 0.0, -4.0)

	critical_callout.show_pair(
		word.get("english", ""),
		word.get("japanese", ""),
		color,
		word.get("id", "")
	)
