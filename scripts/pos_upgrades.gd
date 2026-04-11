extends Node
## pocv4 per-POS upgrade state (replaces the earlier per-word version).
##
## Each part of speech — noun / verb / adjective / adverb — tracks its own
## {power, speed, pierce} trio. All bullets of that POS share those bonuses.
## This makes the level-up choice feel meaningful without demanding the
## player track 20 individual upgrade lines.
##
##   power  -> bonus damage on normal/strong bullet hits
##   speed  -> bullet velocity multiplier
##   pierce -> number of extra enemies the bullet passes through
##
## Resets on each new run.

enum Stat { POWER, SPEED, PIERCE }

const MAX_LEVEL_PER_STAT := 10

const STAT_LABELS := {
	Stat.POWER: "威力UP",
	Stat.SPEED: "弾速UP",
	Stat.PIERCE: "貫通UP",
}

const POS_LIST := ["noun", "verb", "adjective", "adverb"]

var _upgrades: Dictionary = {}  # pos (String) -> {power, speed, pierce}

signal upgrade_applied(pos: String, stat: int)

func reset_run() -> void:
	_upgrades.clear()

func _ensure(pos: String) -> Dictionary:
	if not _upgrades.has(pos):
		_upgrades[pos] = {"power": 0, "speed": 0, "pierce": 0}
	return _upgrades[pos]

# ---------- queries ----------

func get_stats(pos: String) -> Dictionary:
	if pos == "":
		return {"power": 0, "speed": 0, "pierce": 0}
	return _ensure(pos).duplicate()

func get_power(pos: String) -> int:
	if pos == "":
		return 0
	return int(_ensure(pos).power)

func get_speed(pos: String) -> int:
	if pos == "":
		return 0
	return int(_ensure(pos).speed)

func get_pierce(pos: String) -> int:
	if pos == "":
		return 0
	return int(_ensure(pos).pierce)

func total_level(pos: String) -> int:
	var d: Dictionary = _ensure(pos)
	return int(d.power) + int(d.speed) + int(d.pierce)

func can_upgrade(pos: String, stat: int) -> bool:
	var d: Dictionary = _ensure(pos)
	match stat:
		Stat.POWER:
			return int(d.power) < MAX_LEVEL_PER_STAT
		Stat.SPEED:
			return int(d.speed) < MAX_LEVEL_PER_STAT
		Stat.PIERCE:
			return int(d.pierce) < MAX_LEVEL_PER_STAT
	return false

# ---------- mutations ----------

func apply_upgrade(pos: String, stat: int) -> void:
	if pos == "":
		return
	var d: Dictionary = _ensure(pos)
	match stat:
		Stat.POWER:
			d.power = mini(int(d.power) + 1, MAX_LEVEL_PER_STAT)
		Stat.SPEED:
			d.speed = mini(int(d.speed) + 1, MAX_LEVEL_PER_STAT)
		Stat.PIERCE:
			d.pierce = mini(int(d.pierce) + 1, MAX_LEVEL_PER_STAT)
	upgrade_applied.emit(pos, stat)

# ---------- bullet-side helpers ----------

## Extra damage added on top of the base HitJudge value. Normal hits get
## +power, strong hits get +power*2.
func bonus_damage(pos: String, hit_type: int) -> int:
	var power: int = get_power(pos)
	# HitJudge.HitType.NORMAL = 0, STRONG = 1, CRITICAL = 2
	if hit_type == 0:
		return power
	if hit_type == 1:
		return power * 2
	return 0

## Bullet velocity multiplier. Each speed point adds 25% speed.
func velocity_multiplier(pos: String) -> float:
	return 1.0 + 0.25 * float(get_speed(pos))

## How many enemies a bullet can hit before despawning (1 = no pierce).
func hit_budget(pos: String) -> int:
	return 1 + get_pierce(pos)
