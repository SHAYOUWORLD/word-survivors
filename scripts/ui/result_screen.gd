extends Control
## Post-run result + 4-choice mini quiz + correlation summary.
## This is the PoC's measurement endpoint: the scoring hypothesis is
## "words with more critical hits → higher quiz accuracy".

@onready var title_label: Label = $Title
@onready var stats_label: Label = $Stats
@onready var quiz_container: VBoxContainer = $QuizPanel/VBox
@onready var question_label: Label = $QuizPanel/VBox/Question
@onready var choice_row: VBoxContainer = $QuizPanel/VBox/Choices
@onready var feedback_label: Label = $QuizPanel/VBox/Feedback
@onready var progress_label: Label = $QuizPanel/VBox/Progress
@onready var summary_panel: PanelContainer = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/VBox/SummaryLabel
@onready var correlation_label: Label = $SummaryPanel/VBox/CorrelationLabel
@onready var per_word_list: VBoxContainer = $SummaryPanel/VBox/Scroll/List
@onready var retry_button: Button = $SummaryPanel/VBox/Buttons/RetryButton
@onready var quit_button: Button = $SummaryPanel/VBox/Buttons/QuitButton

var _quiz_words: Array = []        # word dicts, shuffled
var _current_idx: int = 0
var _quiz_start_time: int = 0
var _per_word_results: Dictionary = {}  # word_id -> { correct, response_time_ms, critical_hits_during_run }

func _ready() -> void:
	_style_buttons()
	_populate_stats()
	_init_quiz()
	AudioManager.play_bgm("title", 1.0)
	retry_button.pressed.connect(_on_retry)
	quit_button.pressed.connect(_on_quit)
	summary_panel.visible = false

func _populate_stats() -> void:
	var data: Dictionary = LearningTracker.current_run_data
	var survived: bool = data.get("survived", false)
	var dur: float = data.get("run_duration", 0.0)
	var kills: int = GameManager.kills
	var crit_total: int = 0
	for _id in data.word_stats:
		crit_total += int(data.word_stats[_id].get("critical_hits", 0))
	title_label.text = "SURVIVED!" if survived else "GAME OVER"
	title_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.5, 1) if survived else Color(1, 0.4, 0.4, 1)
	)
	stats_label.text = "プレイ時間: %s   |   撃破: %d   |   クリティカル合計: %d" % [
		GameManager.format_time(dur), kills, crit_total
	]

func _init_quiz() -> void:
	var held_ids: Array = LearningTracker.current_run_data.word_stats.keys()
	# Filter to words that were actually in-play (held and fired).
	_quiz_words.clear()
	for id in held_ids:
		var w = WordDatabase.get_word(id)
		if not w.is_empty() and int(LearningTracker.current_run_data.word_stats[id].get("times_fired", 0)) > 0:
			_quiz_words.append(w)
	_quiz_words.shuffle()
	if _quiz_words.is_empty():
		# No firing happened — skip quiz and go to summary.
		_show_summary()
		return
	_current_idx = 0
	feedback_label.text = ""
	_show_question()

func _show_question() -> void:
	for c in choice_row.get_children():
		c.queue_free()
	feedback_label.text = ""
	var word: Dictionary = _quiz_words[_current_idx]
	progress_label.text = "問題 %d / %d" % [_current_idx + 1, _quiz_words.size()]
	question_label.text = "「%s」 の意味は？" % word.get("english", "")

	# Build 4 choices = correct JA + 3 distractors.
	var choices: Array = [word.get("japanese", "")]
	var distractors: Array = []
	for w in WordDatabase.all_words:
		if w.get("id", "") != word.get("id", ""):
			distractors.append(w.get("japanese", ""))
	distractors.shuffle()
	for i in 3:
		if i < distractors.size():
			choices.append(distractors[i])
	choices.shuffle()

	for ja in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(600, 60)
		btn.text = ja
		btn.add_theme_font_size_override("font_size", 28)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_style_quiz_button(btn)
		btn.pressed.connect(_on_choice_selected.bind(ja, word))
		choice_row.add_child(btn)

	_quiz_start_time = Time.get_ticks_msec()

func _on_choice_selected(chosen_ja: String, word: Dictionary) -> void:
	var correct: bool = (chosen_ja == word.get("japanese", ""))
	var elapsed_ms: int = Time.get_ticks_msec() - _quiz_start_time
	var word_id: String = word.get("id", "")
	_per_word_results[word_id] = {
		"correct": correct,
		"response_time_ms": elapsed_ms,
		"critical_hits_during_run": LearningTracker.get_critical_count(word_id),
	}
	if correct:
		feedback_label.text = "○ 正解!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
		AudioManager.play_sfx("synergy")
	else:
		feedback_label.text = "× 不正解  (正解: %s)" % word.get("japanese", "")
		feedback_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
		AudioManager.play_sfx("lose")
	# Disable all buttons.
	for c in choice_row.get_children():
		if c is Button:
			(c as Button).disabled = true
	await get_tree().create_timer(0.9).timeout
	_current_idx += 1
	if _current_idx >= _quiz_words.size():
		_show_summary()
	else:
		_show_question()

func _show_summary() -> void:
	quiz_container.get_parent().visible = false
	summary_panel.visible = true

	var total: int = _per_word_results.size()
	var correct_count: int = 0
	for id in _per_word_results.keys():
		if _per_word_results[id].correct:
			correct_count += 1
	var accuracy: float = 0.0 if total == 0 else float(correct_count) / float(total)

	summary_label.text = "正答率: %d / %d (%d%%)" % [
		correct_count, total, int(round(accuracy * 100.0))
	]

	# Correlation: group by critical count.
	var low: Array = []
	var mid: Array = []
	var high: Array = []
	for id in _per_word_results.keys():
		var r: Dictionary = _per_word_results[id]
		var crit: int = int(r.get("critical_hits_during_run", 0))
		if crit == 0:
			low.append(r)
		elif crit <= 2:
			mid.append(r)
		else:
			high.append(r)
	correlation_label.text = "【仮説検証】クリティカル回数と正答率の相関:\n" + \
		"  クリティカル 0回 の単語 (%d語): 正答率 %s\n" % [low.size(), _acc(low)] + \
		"  クリティカル 1〜2回 の単語 (%d語): 正答率 %s\n" % [mid.size(), _acc(mid)] + \
		"  クリティカル 3回以上 の単語 (%d語): 正答率 %s" % [high.size(), _acc(high)]

	# Per-word list.
	for c in per_word_list.get_children():
		c.queue_free()
	var sorted_ids: Array = _per_word_results.keys()
	sorted_ids.sort_custom(func(a, b):
		return int(_per_word_results[a].critical_hits_during_run) > int(_per_word_results[b].critical_hits_during_run)
	)
	for id in sorted_ids:
		var w: Dictionary = WordDatabase.get_word(id)
		var r: Dictionary = _per_word_results[id]
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 18)
		var mark := "○" if r.correct else "×"
		var color := Color(0.4, 1.0, 0.5, 1) if r.correct else Color(1, 0.5, 0.5, 1)
		row.add_theme_color_override("font_color", color)
		row.text = "%s  %s → %s   (クリ %d回, %dms)" % [
			mark, w.get("english", ""), w.get("japanese", ""),
			int(r.get("critical_hits_during_run", 0)),
			int(r.get("response_time_ms", 0)),
		]
		per_word_list.add_child(row)

	# Persist + print JSON dump.
	var quiz_dump: Dictionary = {
		"total_questions": total,
		"correct_answers": correct_count,
		"accuracy": accuracy,
		"per_word": _per_word_results,
	}
	LearningTracker.set_quiz_results(quiz_dump)
	LearningTracker.dump_to_console()

func _acc(arr: Array) -> String:
	if arr.is_empty():
		return "-"
	var c: int = 0
	for r in arr:
		if r.correct:
			c += 1
	return "%d / %d (%d%%)" % [c, arr.size(), int(round(float(c) / arr.size() * 100.0))]

func _style_buttons() -> void:
	for btn in [retry_button, quit_button]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.1, 0.12, 0.18, 0.95)
		normal.border_color = Color(0.9, 0.8, 0.3, 1.0)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(6)
		var hover := normal.duplicate()
		hover.bg_color = Color(0.22, 0.26, 0.36, 1.0)
		hover.border_color = Color(1, 1, 0.7, 1)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("focus", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
		btn.add_theme_font_size_override("font_size", 22)
		btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))

func _style_quiz_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	normal.border_color = Color(0.6, 0.6, 0.7, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.26, 0.36, 1.0)
	hover.border_color = Color(1, 1, 0.6, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))

func _on_retry() -> void:
	AudioManager.play_sfx("button")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	AudioManager.play_sfx("button")
	get_tree().quit()
