extends CharacterBody2D
## Enemy: shows an English word and walks toward the player. pocv5: an enemy
## can only be killed by a Japanese bullet whose id matches this enemy's id.
## On death, registers the kill with GameManager (which handles the
## KILLS_PER_QUIZ quiz trigger) and spawns a colored particle burst.

var word_data: Dictionary = {}
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

	label.text = word_data.get("english", "?")
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	hint_label.text = ""
	hint_label.visible = false

	await get_tree().process_frame
	var main_sz: Vector2 = label.get_minimum_size()
	var total_w: float = main_sz.x + 24.0
	var total_h: float = main_sz.y + 16.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(total_w, total_h)
	$CollisionShape2D.shape = shape
	bg.offset_left = -total_w * 0.5
	bg.offset_right = total_w * 0.5
	bg.offset_top = -total_h * 0.5
	bg.offset_bottom = total_h * 0.5
	bg.color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.78)

func _physics_process(_delta: float) -> void:
	if _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

## pocv5: enemies are instakilled by a matching bullet. The amount and
## bullet_word are kept in the signature for backwards compatibility with
## anything still calling this, but only the death matters here.
func take_damage(_amount: int, _bullet_word: Dictionary) -> void:
	if _dying:
		return
	_dying = true
	call_deferred("die")

func die() -> void:
	GameManager.register_kill(word_data)

	var FxSpawner = preload("res://scripts/fx_spawner.gd")
	var pos: String = word_data.get("pos", "noun")
	var color: Color = WordDatabase.get_pos_color(pos)
	color.a = 1.0
	FxSpawner.spawn_burst(get_parent(), global_position, color, 18, 1.3)

	queue_free()
