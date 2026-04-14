extends CharacterBody2D
## Player: move-only. HP + contact damage. pocv5 strips out EXP/level — the
## levelling loop was replaced by the KILLS_PER_QUIZ quiz → bullet rotation
## cycle.
## BulletSystem (child node) handles all firing.

const MOVE_SPEED: float = 200.0
const MAX_HP: int = 100
const DAMAGE_INVULN: float = 0.5
const CONTACT_DAMAGE: int = 5

signal hp_changed(current: int, maxv: int)
signal died
signal hit_taken

var current_hp: int = MAX_HP

var _damage_cooldown: float = 0.0

@onready var hurt_box: Area2D = $HurtBox
@onready var sprite: ColorRect = $Sprite
@onready var glow: ColorRect = $Glow

func _ready() -> void:
	add_to_group("player")
	hp_changed.emit(current_hp, MAX_HP)

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		velocity = Vector2.ZERO
		return
	var vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if vec.length() > 1.0:
		vec = vec.normalized()
	velocity = vec * MOVE_SPEED
	move_and_slide()

	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta
	else:
		for b in hurt_box.get_overlapping_bodies():
			if b and b.is_in_group("enemies"):
				take_damage(CONTACT_DAMAGE)
				break

	glow.rotation += delta * 2.0

func take_damage(amount: int) -> void:
	if _damage_cooldown > 0.0 or current_hp <= 0:
		return
	_damage_cooldown = DAMAGE_INVULN
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, MAX_HP)
	hit_taken.emit()
	modulate = Color(1.8, 0.5, 0.5, 1.0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.25)
	AudioManager.play_sfx("damage", 0.08)
	if current_hp <= 0:
		AudioManager.play_sfx("game_over")
		died.emit()
