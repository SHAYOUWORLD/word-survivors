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
	# pocv4: bullets carry the ENGLISH word, matching the enemies the player
	# is shooting at. Critical hits (same id) become a visually direct
	# en=en collision, while the JA payoff comes via the critical callout.
	if is_node_ready():
		_apply_visuals(word.get("english", "?"), color)
	else:
		call_deferred("_apply_visuals", word.get("english", "?"), color)

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
	var bullet_pos: String = word_data.get("pos", "")
	var hit_type: int = HitJudge.judge(word_data, enemy.word_data)
	var dmg: int = HitJudge.damage_for(hit_type) + PosUpgrades.bonus_damage(bullet_pos, hit_type)
	enemy.take_damage(dmg, hit_type, word_data)
	_hit_enemies.append(enemy)

	# Tell the main scene to play feedback for this hit.
	var main: Node = get_tree().current_scene
	if main and main.has_method("on_bullet_hit"):
		main.on_bullet_hit(hit_type, word_data, enemy.word_data, enemy.global_position)

	# Pierce: the bullet can keep flying through up to N enemies. Default
	# hit_budget is 1 (no pierce); each pierce upgrade on this POS adds one
	# more enemy.
	if _hit_enemies.size() >= PosUpgrades.hit_budget(bullet_pos):
		queue_free()
