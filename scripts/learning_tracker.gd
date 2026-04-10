extends Node
## Records per-word interaction stats across a run. This is the data the
## PoC hypothesis is measured against.

const HitType = preload("res://scripts/hit_judge.gd").HitType

var current_run_data: Dictionary = {}
var last_quiz_results: Dictionary = {}

func _ready() -> void:
	_reset()

func start_run() -> void:
	_reset()
	current_run_data.run_id = _generate_run_id()

func _reset() -> void:
	current_run_data = {
		"run_id": "",
		"run_duration": 0.0,
		"survived": false,
		"word_stats": {},
		"levelup_choices": [],
	}

func _ensure_word(word_id: String) -> void:
	if not current_run_data.word_stats.has(word_id):
		current_run_data.word_stats[word_id] = {
			"times_fired": 0,
			"normal_hits": 0,
			"strong_hits": 0,
			"critical_hits": 0,
			"critical_timestamps": [],
			"total_screen_time": 0.0,
		}

func record_fire(word_id: String) -> void:
	_ensure_word(word_id)
	current_run_data.word_stats[word_id].times_fired += 1

func record_hit(word_id: String, hit_type: int, t: float) -> void:
	_ensure_word(word_id)
	var s: Dictionary = current_run_data.word_stats[word_id]
	match hit_type:
		HitType.NORMAL:
			s.normal_hits += 1
		HitType.STRONG:
			s.strong_hits += 1
		HitType.CRITICAL:
			s.critical_hits += 1
			s.critical_timestamps.append(float(t))

func record_levelup_choice(t: float, offered: Array, chosen: String) -> void:
	current_run_data.levelup_choices.append({
		"time": float(t),
		"offered": offered.duplicate(),
		"chosen": chosen,
	})

func add_screen_time(word_id: String, seconds: float) -> void:
	_ensure_word(word_id)
	current_run_data.word_stats[word_id].total_screen_time += seconds

func end_run(survived: bool, duration: float) -> void:
	current_run_data.survived = survived
	current_run_data.run_duration = duration

func get_critical_count(word_id: String) -> int:
	var s: Dictionary = current_run_data.word_stats.get(word_id, {})
	return int(s.get("critical_hits", 0))

func set_quiz_results(r: Dictionary) -> void:
	last_quiz_results = r

func export_all() -> Dictionary:
	return {
		"tracking_data": current_run_data,
		"quiz_results": last_quiz_results,
	}

func dump_to_console() -> void:
	print("======= LEARNING TRACKER DUMP =======")
	print(JSON.stringify(export_all(), "  "))
	print("=====================================")

func _generate_run_id() -> String:
	var t := Time.get_unix_time_from_system()
	var r := randi()
	return "run_%d_%d" % [int(t), r]
