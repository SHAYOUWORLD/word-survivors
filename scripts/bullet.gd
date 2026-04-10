extends Area2D
## Bullet = an English word flying toward an enemy. Carries its own word dict
## and delegates hit judgment to HitJudge.

const HitJudge := preload("res://scripts/hit_judge.gd")

var word_data: Dictionary = {}
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var _age: float = 0.0
var _hit_enemies: Array = []

@onready var label: Label = $Label

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2  # detect Enemy CharacterBody2D
	body_entered.connect(_on_body_entered)

func setup(word: Dictionary, vel: Vector2, life: float = 2.0) -> void:
	word_data = word
	velocity = vel
	lifetime = life
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	if is_node_ready():
		_apply_visuals(word.get("japanese", "?"), color)
	else:
		call_deferred("_apply_visuals", word.get("japanese", "?"), color)

func _apply_visuals(text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += velocity * delta
	# Gentle rotation for visual life.
	rotation = velocity.angle() * 0.0

func _on_body_entered(body: Node) -> void:
	var enemy := body
	if enemy == null or _hit_enemies.has(enemy):
		return
	if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
		return
	var hit_type: int = HitJudge.judge(word_data, enemy.word_data)
	var dmg: int = HitJudge.damage_for(hit_type)
	enemy.take_damage(dmg, hit_type, word_data)
	_hit_enemies.append(enemy)

	# Tell the main scene to play feedback for this hit.
	var main: Node = get_tree().current_scene
	if main and main.has_method("on_bullet_hit"):
		main.on_bullet_hit(hit_type, word_data, enemy.word_data, enemy.global_position)

	queue_free()
