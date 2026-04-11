extends Area2D
## Bullet = a Japanese word flying toward an enemy. pocv5: the bullet kills
## an enemy only if its word id matches the enemy's word id (i.e. the JA
## bullet means the EN enemy). Non-matching enemies are ignored and the
## bullet passes through them.

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

func _on_body_entered(body: Node) -> void:
	var enemy := body
	if enemy == null or _hit_enemies.has(enemy):
		return
	if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
		return
	_hit_enemies.append(enemy)

	var bullet_id: String = word_data.get("id", "")
	var enemy_id: String = enemy.word_data.get("id", "")
	if bullet_id == "" or bullet_id != enemy_id:
		# Mismatch: bullet passes through harmlessly. Don't even play feedback.
		return

	# Match: instakill.
	enemy.take_damage(999, word_data)

	var main: Node = get_tree().current_scene
	if main and main.has_method("on_bullet_match"):
		main.on_bullet_match(word_data, enemy.word_data, enemy.global_position)

	# One kill per bullet — disappear on the matched kill.
	queue_free()
