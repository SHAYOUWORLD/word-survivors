extends CharacterBody2D
## Enemy: shows an English word, with a Japanese hint label underneath whose
## visibility decays based on run-local kill count (see MasteryTracker).
## Walks toward the player. Killed by bullet.gd via take_damage().

const MAX_HP: int = 3
const CONTACT_DAMAGE_INTERNAL := 5  # handled player-side; retained for clarity

var word_data: Dictionary = {}
var hp: int = MAX_HP
var move_speed: float = 60.0
var _dying: bool = false
var _player: Node2D = null

@onready var label: Label = $Label
@onready var hint_label: Label = $HintLabel
@onready var bg: ColorRect = $BG

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")

func setup(word: Dictionary, speed: float) -> void:
	word_data = word
	move_speed = speed
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

	# Hint label = Japanese, degraded based on how many times this word has
	# been killed already this run. 0 kills = full, 1–2 = obfuscated, 3+ = none.
	var hint_text: String = MasteryTracker.build_hint_text(word_data)
	hint_label.text = hint_text
	hint_label.visible = hint_text != ""

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
	bg.color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.75)

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

func die(hit_type: int) -> void:
	GameManager.register_kill()
	MasteryTracker.record_kill(word_data.get("id", ""))

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

	queue_free()
