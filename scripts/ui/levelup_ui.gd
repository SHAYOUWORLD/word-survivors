extends CanvasLayer
## Levelup choice panel: 3 Japanese words (the bullet side), NO English shown.
## The English meaning is learned by encountering enemies in-game.

signal choice_selected(word_id: String, offered: Array)

@onready var root_panel: Control = $Root
@onready var title_label: Label = $Root/Panel/VBox/Title
@onready var button_row: HBoxContainer = $Root/Panel/VBox/Row

var _offered_ids: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_panel.visible = false

func show_choices(held_ids: Array) -> void:
	_offered_ids.clear()
	for c in button_row.get_children():
		c.queue_free()

	var choices: Array = _generate_choices(held_ids, 3)
	_offered_ids = choices.map(func(w): return w.get("id", ""))

	for word in choices:
		var btn := _make_button(word)
		button_row.add_child(btn)

	root_panel.visible = true
	get_tree().paused = true
	AudioManager.play_sfx("choice", 0.0, -4.0)

	# Grab focus on the first button so keyboard / controller can select.
	await get_tree().process_frame
	if button_row.get_child_count() > 0:
		var first: Button = button_row.get_child(0)
		first.grab_focus()

func hide_panel() -> void:
	root_panel.visible = false
	get_tree().paused = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not root_panel.visible:
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
	if idx >= 0 and idx < button_row.get_child_count():
		var btn: Button = button_row.get_child(idx)
		btn.emit_signal("pressed")
		get_viewport().set_input_as_handled()

func _generate_choices(held_ids: Array, n: int) -> Array:
	var pool: Array = []
	for w in WordDatabase.all_words:
		if not held_ids.has(w.get("id", "")):
			pool.append(w)
	pool.shuffle()
	if pool.size() <= n:
		return pool
	# Bias towards diversity: prefer each POS to appear once if possible.
	var picked: Array = []
	var used_pos: Dictionary = {}
	for w in pool:
		var pos: String = w.get("pos", "")
		if not used_pos.has(pos):
			picked.append(w)
			used_pos[pos] = true
		if picked.size() >= n:
			break
	for w in pool:
		if picked.size() >= n:
			break
		if not picked.has(w):
			picked.append(w)
	return picked.slice(0, n)

func _make_button(word: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 220)
	var pos: String = word.get("pos", "noun")
	var color: Color = WordDatabase.get_pos_color(pos)
	var pos_label_ja: String = WordDatabase.get_pos_label_ja(pos)
	btn.text = "[%s]\n\n%s" % [pos_label_ja, word.get("japanese", "")]
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	normal.border_color = color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	var hover := normal.duplicate()
	hover.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 1.0)
	hover.border_color = Color(1, 1, 1, 1)
	hover.set_border_width_all(4)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))
	btn.pressed.connect(_on_selected.bind(word.get("id", "")))
	return btn

func _on_selected(word_id: String) -> void:
	AudioManager.play_sfx("button")
	hide_panel()
	choice_selected.emit(word_id, _offered_ids.duplicate())
