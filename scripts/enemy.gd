extends CharacterBody2D
## Enemy: shows an English word. Walks toward the player. Killed by bullet.gd
## via take_damage(). On death, routes through MasteryTracker to decide whether
## to show the ja+pronunciation popup (kills 1-3 in PHASE_A) or fire the
## 4-choice quiz (kill 4, or any kill while in REVIEW_DUE).

const MAX_HP: int = 3
const CONTACT_DAMAGE_INTERNAL := 5  # handled player-side; retained for clarity
const WORD_POPUP_SCENE := preload("res://scenes/word_popup.tscn")

var word_data: Dictionary = {}
var hp: int = MAX_HP
var move_speed: float = 60.0
var _dying: bool = false
var _player: Node2D = null
## True for enemies injected by the review scheduler. Visually marked and
## always routes death into the quiz.
var is_review_enemy: bool = false

@onready var label: Label = $Label
@onready var hint_label: Label = $HintLabel
@onready var bg: ColorRect = $BG

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")

func setup(word: Dictionary, speed: float, review: bool = false) -> void:
	word_data = word
	move_speed = speed
	is_review_enemy = review
	if is_node_ready():
		_apply_visuals()
	else:
		call_deferred("_apply_visuals")

func _apply_visuals() -> void:
	var pos: String = word_data.get("pos", "noun")
	var color: Color = WordDatabase.get_pos_color(pos)

	# Main label = English word (the thing the player is learning).
	label.text = word_data.get("english", "?")
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	# Hint label is unused in pocv4 — the ja+pronunciation popup replaces it.
	# Review enemies get a "★ REVIEW" tag so the player notices they're back.
	if is_review_enemy:
		hint_label.text = "★ REVIEW ★"
		hint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		hint_label.visible = true
	else:
		hint_label.text = ""
		hint_label.visible = false

	# Fit collision + background to the combined label bounds.
	await get_tree().process_frame
	var main_sz: Vector2 = label.get_minimum_size()
	var hint_sz: Vector2 = Vector2.ZERO
	if hint_label.visible:
		hint_sz = hint_label.get_minimum_size()
	var total_w: float = max(main_sz.x, hint_sz.x) + 24.0
	var total_h: float = main_sz.y + hint_sz.y + 16.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(total_w, total_h)
	$CollisionShape2D.shape = shape
	bg.offset_left = -total_w * 0.5
	bg.offset_right = total_w * 0.5
	bg.offset_top = -total_h * 0.5
	bg.offset_bottom = total_h * 0.5
	var bg_tint: float = 0.35 if is_review_enemy else 0.2
	bg.color = Color(color.r * bg_tint, color.g * bg_tint, color.b * bg_tint, 0.78)

func _physics_process(_delta: float) -> void:
	if _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func take_damage(amount: int, hit_type: int, bullet_word: Dictionary) -> void:
	if _dying:
		return
	hp = max(0, hp - amount)
	LearningTracker.record_hit(bullet_word.get("id", ""), hit_type, GameManager.run_time)
	if hp <= 0 or hit_type == 2:  # CRITICAL always kills
		_dying = true
		call_deferred("die", hit_type)

func die(_hit_type: int) -> void:
	GameManager.register_kill()

	var FxSpawner = preload("res://scripts/fx_spawner.gd")
	var pos: String = word_data.get("pos", "noun")
	var color: Color = WordDatabase.get_pos_color(pos)
	color.a = 1.0
	FxSpawner.spawn_burst(get_parent(), global_position, color, 18, 1.3)

	# Spawn exp gem.
	var gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
	var gem = gem_scene.instantiate()
	get_parent().add_child(gem)
	gem.global_position = global_position

	# --- pocv4 progress update ---
	var word_id: String = word_data.get("id", "")
	var outcome: Dictionary = MasteryTracker.on_kill(word_id)
	var action: String = outcome.get("action", "none")
	if action == "popup":
		var kc: int = int(outcome.get("kill_count", 1))
		_spawn_word_popup(kc)
	elif action == "quiz":
		var main: Node = get_tree().current_scene
		if main and main.has_method("on_enemy_triggered_quiz"):
			main.on_enemy_triggered_quiz(word_data, bool(outcome.get("is_review", false)), global_position)

	queue_free()

func _spawn_word_popup(kill_count: int) -> void:
	var popup = WORD_POPUP_SCENE.instantiate()
	get_parent().add_child(popup)
	popup.global_position = global_position + Vector2(0, -20)
	popup.setup(word_data, kill_count)
