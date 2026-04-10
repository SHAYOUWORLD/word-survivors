extends Area2D

const EXP_AMOUNT := 1
const COLLECT_INITIAL_SPEED := 250.0
const COLLECT_ACCEL := 1400.0

var _player: Node2D = null
var _collecting: bool = false
var _speed: float = COLLECT_INITIAL_SPEED

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("exp_gem")
	collision_layer = 32
	collision_mask = 0

func start_collection(p: Node2D) -> void:
	_player = p
	_collecting = true

func _physics_process(delta: float) -> void:
	if not _collecting or _player == null or not is_instance_valid(_player):
		return
	var to := _player.global_position - global_position
	var dist := to.length()
	_speed += COLLECT_ACCEL * delta
	global_position += to.normalized() * min(_speed * delta, dist)
	if dist < 10.0:
		_player.add_exp(EXP_AMOUNT)
		queue_free()
