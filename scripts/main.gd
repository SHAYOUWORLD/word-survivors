extends Node2D
## Main gameplay scene for pocv4.
## Responsibilities:
## - Wires player, spawner, camera, HUD, levelup UI, critical callout, quiz panel
## - Drives the 5-minute run
## - Receives bullet-hit events via on_bullet_hit() and dispatches feedback:
##   damage numbers, particles, screen shake, hitstop, critical callout, SE
## - Handles the pocv4 quiz flow: kill 4 on a word (or any kill during review)
##   triggers a 4-choice JA->EN quiz. Correct = big explosion clearing all
##   enemies + schedule reviews. Wrong = word resets to kill_count 0.

const HitJudge := preload("res://scripts/hit_judge.gd")
const FxSpawner := preload("res://scripts/fx_spawner.gd")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/damage_number.tscn")

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var levelup_ui: CanvasLayer = $LevelUpUI
@onready var critical_callout: CanvasLayer = $CriticalCallout
@onready var quiz_panel: CanvasLayer = $QuizPanel
@onready var grid: Node2D = $Grid

var _shake_amount: float = 0.0
var _shake_decay: float = 24.0

func _ready() -> void:
	randomize()
	GameManager.start_run()
	LearningTracker.start_run()
	MasteryTracker.reset_run()
	PosUpgrades.reset_run()

	var bs: Node = player.get_node("BulletSystem")
	bs.attach_to_player(player)

	# Seed 4 initial words: one per POS, randomly chosen.
	for pos in WordDatabase.all_pos_list():
		var w: Dictionary = WordDatabase.get_random_word_by_pos(pos)
		if not w.is_empty():
			bs.add_word(w)

	hud.bind_player(player)

	player.level_up.connect(_on_player_level_up)
	player.died.connect(_on_player_died)
	player.hit_taken.connect(_on_player_hit)
	levelup_ui.result_chosen.connect(_on_levelup_result)
	quiz_panel.answered.connect(_on_quiz_answered)

	AudioManager.play_bgm("gameplay", 0.6)

func _process(delta: float) -> void:
	if player and is_instance_valid(player):
		var offset := Vector2.ZERO
		if _shake_amount > 0.01:
			offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
			_shake_amount = max(0.0, _shake_amount - _shake_decay * delta)
		camera.global_position = player.global_position + offset

	if GameManager.state == GameManager.State.RESULT:
		_goto_result(true)
	elif GameManager.state == GameManager.State.GAMEOVER:
		_goto_result(false)

func shake(amount: float) -> void:
	_shake_amount = max(_shake_amount, amount)

# Called by bullet.gd on every successful hit.
func on_bullet_hit(hit_type: int, bullet_word: Dictionary, enemy_word: Dictionary, enemy_pos: Vector2) -> void:
	match hit_type:
		HitJudge.HitType.NORMAL:
			_play_normal_hit(bullet_word, enemy_pos)
		HitJudge.HitType.STRONG:
			_play_strong_hit(bullet_word, enemy_pos)
		HitJudge.HitType.CRITICAL:
			_play_critical_hit(bullet_word, enemy_word, enemy_pos)

func _play_normal_hit(_bullet_word: Dictionary, pos: Vector2) -> void:
	var dn = DAMAGE_NUMBER_SCENE.instantiate()
	add_child(dn)
	dn.global_position = pos + Vector2(0, -30)
	dn.setup_normal(1)
	AudioManager.play_sfx("button", 0.15, -16.0)

func _play_strong_hit(bullet_word: Dictionary, pos: Vector2) -> void:
	var color: Color = WordDatabase.get_pos_color(bullet_word.get("pos", "noun"))
	var dn = DAMAGE_NUMBER_SCENE.instantiate()
	add_child(dn)
	dn.global_position = pos + Vector2(0, -30)
	dn.setup_strong(3, color)
	FxSpawner.spawn_sparkles(self, pos, color)
	AudioManager.play_sfx("hit", 0.1, -4.0)

func _play_critical_hit(bullet_word: Dictionary, enemy_word: Dictionary, pos: Vector2) -> void:
	var color: Color = WordDatabase.get_pos_color(enemy_word.get("pos", "noun"))
	# Text callout. On a critical hit bullet_word.id == enemy_word.id so either
	# dict exposes the same fields — we pull english from the enemy side
	# (what the player is staring at) and japanese from the bullet side.
	critical_callout.show_pair(
		enemy_word.get("english", ""),
		bullet_word.get("japanese", ""),
		color,
		enemy_word.get("id", "")
	)
	# Massive particle burst
	FxSpawner.spawn_mega_burst(self, pos, color)
	FxSpawner.spawn_sparkles(self, pos, Color(1, 0.95, 0.6, 1))
	# Screen shake
	shake(14.0)
	# Hitstop
	_hitstop(0.05)
	# Audio stack
	AudioManager.play_sfx("boom", 0.0, -2.0)
	AudioManager.play_sfx("hit_heavy", 0.0, -4.0)
	AudioManager.play_sfx("synergy", 0.0, -6.0)

func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.02
	# process_always=true, physics=false, ignore_time_scale=true so the
	# timer still fires while the world runs at 0.02x.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_player_hit() -> void:
	shake(10.0)

func _on_player_level_up() -> void:
	GameManager.set_state(GameManager.State.LEVELUP)
	levelup_ui.show_levelup()

## Simplified pocv4 levelup flow: pick a POS, then pick a stat. The chosen
## POS gets +1 to that stat, applied to every bullet of that POS.
func _on_levelup_result(pos: String, upgrade_stat: int) -> void:
	LearningTracker.record_levelup_choice(
		GameManager.run_time,
		[pos],
		pos
	)
	if pos != "" and upgrade_stat >= 0:
		PosUpgrades.apply_upgrade(pos, upgrade_stat)
		FxSpawner.spawn_levelup_beam(self, player.global_position)
	GameManager.set_state(GameManager.State.PLAYING)

func _on_player_died() -> void:
	GameManager.trigger_game_over()

func _goto_result(survived: bool) -> void:
	LearningTracker.end_run(survived, GameManager.run_time)
	set_process(false)
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")

# ---------- pocv4 quiz flow ----------

## Called from enemy.die() when MasteryTracker says the kill should open a
## quiz (4th kill in PHASE_A, or any kill during REVIEW_DUE).
func on_enemy_triggered_quiz(word_data: Dictionary, is_review: bool, _enemy_pos: Vector2) -> void:
	GameManager.set_state(GameManager.State.QUIZ)
	quiz_panel.show_quiz(word_data, is_review)

func _on_quiz_answered(word_id: String, correct: bool, _is_review: bool) -> void:
	var word: Dictionary = WordDatabase.get_word(word_id)
	if correct:
		MasteryTracker.mark_quiz_correct(word_id, GameManager.run_time)
		GameManager.set_state(GameManager.State.PLAYING)
		_play_big_explosion(word)
		if MasteryTracker.all_mastered(_all_word_ids()):
			# All words fully mastered — trigger game clear after the
			# explosion has had a moment to play.
			await get_tree().create_timer(1.6).timeout
			GameManager.trigger_survive()
	else:
		MasteryTracker.mark_quiz_wrong(word_id)
		GameManager.set_state(GameManager.State.PLAYING)
		# Brief visual acknowledgment: small shake + sfx. The word is now
		# back in PHASE_A — no extra bookkeeping required here.
		shake(8.0)
		AudioManager.play_sfx("damage")

## Clears every on-screen enemy with a cascading burst effect, shakes the
## screen hard, and stacks the audio for maximum dopamine. Used when the
## quiz is answered correctly.
func _play_big_explosion(word: Dictionary) -> void:
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	color.a = 1.0

	# Central mega burst at the player.
	if player and is_instance_valid(player):
		FxSpawner.spawn_mega_burst(self, player.global_position, color)
		FxSpawner.spawn_sparkles(self, player.global_position, Color(1, 0.95, 0.6, 1))

	# Wipe every enemy with a per-enemy burst. Do NOT call die() — we don't
	# want mastery-side effects from these kills.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		# All nodes in the "enemies" group are instances of enemy.tscn and
		# expose word_data. Access the variant property directly.
		var val = en.get("word_data")
		var en_pos_name: String = "noun"
		if val is Dictionary:
			en_pos_name = (val as Dictionary).get("pos", "noun")
		var en_color: Color = WordDatabase.get_pos_color(en_pos_name)
		en_color.a = 1.0
		FxSpawner.spawn_burst(self, en.global_position, en_color, 14, 1.0)
		GameManager.register_kill()
		en.queue_free()

	# Shake + hitstop for weight.
	shake(22.0)
	_hitstop(0.08)

	# Audio stack.
	AudioManager.play_sfx("boom", 0.0, 0.0)
	AudioManager.play_sfx("hit_heavy", 0.0, -2.0)
	AudioManager.play_sfx("synergy", 0.0, -4.0)

	# Big visual callout: english == japanese, like a critical hit, to burn
	# the pair in at the mastery moment.
	critical_callout.show_pair(
		word.get("english", ""),
		word.get("japanese", ""),
		color,
		word.get("id", "")
	)

func _all_word_ids() -> Array:
	var out: Array = []
	for w in WordDatabase.all_words:
		out.append(w.get("id", ""))
	return out
