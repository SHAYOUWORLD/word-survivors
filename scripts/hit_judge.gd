extends RefCounted
## pocv5: hit judgment reduced to a boolean match check.
## Kept as a module for any callers that still reference HitType constants,
## but bullet.gd now handles the match test inline.

enum HitType {
	MISS = 0,
	MATCH = 1,
}

static func is_match(bullet_word: Dictionary, enemy_word: Dictionary) -> bool:
	if bullet_word.is_empty() or enemy_word.is_empty():
		return false
	return bullet_word.get("id", "") == enemy_word.get("id", "")
