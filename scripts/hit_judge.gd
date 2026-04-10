extends RefCounted
## Pure 3-tier hit judgment: bullet vs enemy word pair.
## Used as a script-level const from bullet.gd / enemy.gd.

enum HitType {
	NORMAL = 0,   # 属性不一致 (1 dmg, small white pop)
	STRONG = 1,   # 属性一致 (3 dmg, colored pop)
	CRITICAL = 2, # 意味一致 (instakill, full dopamine payload)
}

const DAMAGE := {
	HitType.NORMAL: 1,
	HitType.STRONG: 3,
	HitType.CRITICAL: 999,
}

static func judge(bullet_word: Dictionary, enemy_word: Dictionary) -> int:
	if bullet_word.is_empty() or enemy_word.is_empty():
		return HitType.NORMAL
	if bullet_word.get("id", "") == enemy_word.get("id", ""):
		return HitType.CRITICAL
	if bullet_word.get("pos", "") == enemy_word.get("pos", ""):
		return HitType.STRONG
	return HitType.NORMAL

static func damage_for(hit_type: int) -> int:
	return DAMAGE.get(hit_type, 1)
