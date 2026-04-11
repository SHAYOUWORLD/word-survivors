extends CanvasLayer
## 4-choice JA -> EN quiz. Used by pocv4 when an enemy's word reaches kill 4
## (PHASE_A) or when a scheduled review enemy is killed (REVIEW_DUE).
##
## Flow:
##   main.gd calls show_quiz(word_data, is_review)
##   -> pauses game, builds 4 buttons (1 correct + 3 same-POS distractors)
##   -> emits answered(word_id, correct: bool, is_review: bool)
##
## Keyboard shortcuts: 1..4 to select the corresponding button.

signal answered(word_id: String, correct: bool, is_review: bool)

@onready var root: Control = $Root
@onready var ja_label: Label = $Root/Panel/VBox/JALabel
@onready var header: Label = $Root/Panel/VBox/Header
@onready var grid: GridContainer = $Root/Panel/VBox/Grid

var _word: Dictionary = {}
var _is_review: bool = false
var _choices: Array = []        # Array[Dictionary]
var _locked: bool = false       # prevent double-tap after answer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false

func show_quiz(word: Dictionary, is_review: bool) -> void:
	_word = word
	_is_review = is_review
	_locked = false

	for c in grid.get_children():
		c.queue_free()

	_choices = _build_choices(word, 4)
	var correct_id: String = word.get("id", "")

	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	ja_label.text = word.get("japanese", "?")
	ja_label.add_theme_color_override("font_color", color)
	header.text = "復習クイズ" if is_review else "QUIZ — この意味の英単語は？"

	for choice in _choices:
		var btn := _make_button(choice, correct_id)
		grid.add_child(btn)

	root.visible = true
	get_tree().paused = true
	AudioManager.play_sfx("choice", 0.0, -4.0)
	# NOTE: deliberately NOT playing play_voice(correct_id) here — the
	# pronunciation audio would leak the answer and let the player pass
	# the quiz by ear instead of by recognition.

	await get_tree().process_frame
	if grid.get_child_count() > 0:
		var first: Button = grid.get_child(0)
		first.grab_focus()

func hide_panel() -> void:
	root.visible = false
	get_tree().paused = false

func _build_choices(word: Dictionary, n: int) -> Array:
	var correct_id: String = word.get("id", "")
	var correct_pos: String = word.get("pos", "")

	# Prefer same-POS distractors so choices feel tight.
	var same_pos: Array = []
	var other: Array = []
	for w in WordDatabase.all_words:
		if w.get("id", "") == correct_id:
			continue
		if w.get("pos", "") == correct_pos:
			same_pos.append(w)
		else:
			other.append(w)
	same_pos.shuffle()
	other.shuffle()

	var picked: Array = [word]
	for w in same_pos:
		if picked.size() >= n:
			break
		picked.append(w)
	for w in other:
		if picked.size() >= n:
			break
		picked.append(w)

	picked.shuffle()
	return picked

func _make_button(word: Dictionary, correct_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(580, 110)
	btn.text = word.get("english", "")
	btn.add_theme_font_size_override("font_size", 48)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.6, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 0.6, 1))
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	normal.border_color = Color(0.5, 0.5, 0.6, 1)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.28, 1.0)
	hover.border_color = Color(1, 0.9, 0.4, 1)
	hover.set_border_width_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))
	btn.pressed.connect(_on_choice_pressed.bind(word.get("id", ""), correct_id))
	return btn

func _on_choice_pressed(chosen_id: String, correct_id: String) -> void:
	if _locked:
		return
	_locked = true
	var correct: bool = chosen_id == correct_id
	if correct:
		AudioManager.play_sfx("synergy")
	else:
		AudioManager.play_sfx("damage")
	# Small delay so the player sees what they picked.
	await get_tree().create_timer(0.25, true, false, true).timeout
	hide_panel()
	answered.emit(correct_id, correct, _is_review)

func _unhandled_key_input(event: InputEvent) -> void:
	if not root.visible or _locked:
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key: int = (event as InputEventKey).keycode
	var idx: int = -1
	if key == KEY_1:
		idx = 0
	elif key == KEY_2:
		idx = 1
	elif key == KEY_3:
		idx = 2
	elif key == KEY_4:
		idx = 3
	if idx >= 0 and idx < grid.get_child_count():
		var btn: Button = grid.get_child(idx)
		btn.emit_signal("pressed")
		get_viewport().set_input_as_handled()
