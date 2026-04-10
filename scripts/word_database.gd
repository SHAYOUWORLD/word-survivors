extends Node
## Loads words_stage1.json and provides lookup helpers.
## Words are keyed by id (== english by spec). Each word dict is:
##   { id, english, japanese, pos, level }

const DATA_PATH := "res://data/words_stage1.json"

# Canonical POS colors used everywhere.
const POS_COLORS := {
	"noun":      Color8(0x44, 0x88, 0xFF),
	"verb":      Color8(0xFF, 0x44, 0x44),
	"adjective": Color8(0x44, 0xCC, 0x44),
	"adverb":    Color8(0xFF, 0xCC, 0x00),
}

const POS_LABEL_JA := {
	"noun": "名詞",
	"verb": "動詞",
	"adjective": "形容詞",
	"adverb": "副詞",
}

var stage_id: int = 1
var stage_name: String = ""
var all_words: Array = []
var words_by_id: Dictionary = {}
var words_by_pos: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	all_words.clear()
	words_by_id.clear()
	words_by_pos.clear()
	if not FileAccess.file_exists(DATA_PATH):
		push_error("WordDatabase: file not found: %s" % DATA_PATH)
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("WordDatabase: JSON parse error: %s" % json.get_error_message())
		return
	var root: Dictionary = json.data
	stage_id = int(root.get("stage_id", 1))
	stage_name = root.get("stage_name", "")
	for w in root.get("words", []):
		all_words.append(w)
		words_by_id[w.id] = w
		var pos: String = w.pos
		if not words_by_pos.has(pos):
			words_by_pos[pos] = []
		words_by_pos[pos].append(w)
	print("WordDatabase: loaded %d words (stage %d: %s)" % [all_words.size(), stage_id, stage_name])

func get_word(id: String) -> Dictionary:
	return words_by_id.get(id, {})

func get_random_word() -> Dictionary:
	if all_words.is_empty():
		return {}
	return all_words[randi() % all_words.size()]

func get_random_word_by_pos(pos: String) -> Dictionary:
	var pool: Array = words_by_pos.get(pos, [])
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

func get_random_words_by_pos(pos: String, count: int) -> Array:
	var pool: Array = words_by_pos.get(pos, []).duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func get_pos_color(pos: String) -> Color:
	return POS_COLORS.get(pos, Color.WHITE)

func get_pos_label_ja(pos: String) -> String:
	return POS_LABEL_JA.get(pos, pos)

func all_pos_list() -> Array:
	return ["noun", "verb", "adjective", "adverb"]
