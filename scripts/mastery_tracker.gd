extends Node
## Tracks per-word kill count within the current run. Used by enemy.gd to
## decide how much Japanese hint to show under each English enemy word
## (spec Task 1.10: active-recall ramp). Resets on each new run.
##
## Hint levels:
##   0 = full Japanese  (0 kills — first encounter)
##   1 = partial        (1–2 kills — every even-index char replaced by "○")
##   2 = none           (3+ kills — player must recall the meaning)

var kills_by_word_id: Dictionary = {}  # word_id (String) -> int

func reset_run() -> void:
	kills_by_word_id.clear()

func record_kill(word_id: String) -> void:
	if word_id == "":
		return
	kills_by_word_id[word_id] = int(kills_by_word_id.get(word_id, 0)) + 1

func get_kill_count(word_id: String) -> int:
	return int(kills_by_word_id.get(word_id, 0))

func get_hint_level(word_id: String) -> int:
	var k := get_kill_count(word_id)
	if k <= 0:
		return 0
	if k <= 2:
		return 1
	return 2

## Build the hint string shown under the English label based on the current
## kill count. Level 0 -> full Japanese, 1 -> obfuscated, 2 -> empty.
func build_hint_text(word_data: Dictionary) -> String:
	var ja: String = word_data.get("japanese", "")
	if ja == "":
		return ""
	var level := get_hint_level(word_data.get("id", ""))
	match level:
		0:
			return ja
		1:
			return _obfuscate_partial(ja)
		_:
			return ""

## Replaces every even-index character with "○" per spec Task 1.10.
static func _obfuscate_partial(s: String) -> String:
	var out := ""
	for i in s.length():
		if i % 2 == 0:
			out += "○"
		else:
			out += s[i]
	return out
