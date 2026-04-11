extends CanvasLayer
## pocv4 level-up flow — simplified to a two-stage POS upgrade picker:
##
##   Stage POS   : 4 buttons, one per part of speech (名詞/動詞/形容詞/副詞).
##                 Picking one chooses WHICH POS gets powered up.
##   Stage STAT  : 3 buttons — 威力UP / 弾速UP / 貫通UP — for the chosen POS.
##                 The pick is applied through PosUpgrades.
##
## Emits result_chosen(pos, upgrade_stat). A "no pick" (shouldn't happen)
## emits ("", -1).

signal result_chosen(pos: String, upgrade_stat: int)

enum Stage { POS, STAT }

@onready var root_panel: Control = $Root
@onready var header: Label = $Root/Panel/VBox/Header
@onready var sub_header: Label = $Root/Panel/VBox/SubHeader
@onready var prompt: Label = $Root/Panel/VBox/Prompt
@onready var row: HBoxContainer = $Root/Panel/VBox/Row
@onready var feedback: Label = $Root/Panel/VBox/Feedback

var _stage: int = Stage.POS
var _chosen_pos: String = ""
var _locked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_panel.visible = false

# ---------- entry point ----------

func show_levelup() -> void:
	_chosen_pos = ""
	_locked = false
	_enter_pos_stage()

	root_panel.visible = true
	get_tree().paused = true
	AudioManager.play_sfx("choice", 0.0, -4.0)

	await get_tree().process_frame
	_grab_first_enabled()

func hide_panel() -> void:
	root_panel.visible = false
	get_tree().paused = false

# ---------- Stage POS ----------

func _enter_pos_stage() -> void:
	_stage = Stage.POS
	_clear_row()
	feedback.text = ""

	header.text = "LEVEL UP"
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	sub_header.text = "どの品詞を強化する？"
	prompt.text = ""
	prompt.visible = false

	for pos in PosUpgrades.POS_LIST:
		var btn := _make_pos_button(pos)
		row.add_child(btn)

func _make_pos_button(pos: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 220)
	var color: Color = WordDatabase.get_pos_color(pos)
	var pos_ja: String = WordDatabase.get_pos_label_ja(pos)
	var stats: Dictionary = PosUpgrades.get_stats(pos)
	btn.text = "%s\n\n威力 %d\n弾速 %d\n貫通 %d" % [
		pos_ja, int(stats.power), int(stats.speed), int(stats.pierce)
	]
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	_style_button(btn, color)

	btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))
	btn.pressed.connect(_on_pos_pressed.bind(pos))
	return btn

func _on_pos_pressed(pos: String) -> void:
	if _locked:
		return
	_chosen_pos = pos
	AudioManager.play_sfx("button")
	_enter_stat_stage()
	await get_tree().process_frame
	_grab_first_enabled()

# ---------- Stage STAT ----------

func _enter_stat_stage() -> void:
	_stage = Stage.STAT
	_clear_row()
	feedback.text = ""

	var color: Color = WordDatabase.get_pos_color(_chosen_pos)
	var pos_ja: String = WordDatabase.get_pos_label_ja(_chosen_pos)

	header.text = "強化を選べ"
	header.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8, 1))
	sub_header.text = "%s を強化" % pos_ja
	sub_header.add_theme_color_override("font_color", color)
	prompt.visible = false

	for stat in [PosUpgrades.Stat.POWER, PosUpgrades.Stat.SPEED, PosUpgrades.Stat.PIERCE]:
		var btn := _make_stat_button(_chosen_pos, stat, color)
		row.add_child(btn)

func _make_stat_button(pos: String, stat: int, color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(360, 220)

	var stats: Dictionary = PosUpgrades.get_stats(pos)
	var cur: int = 0
	match stat:
		PosUpgrades.Stat.POWER:  cur = int(stats.power)
		PosUpgrades.Stat.SPEED:  cur = int(stats.speed)
		PosUpgrades.Stat.PIERCE: cur = int(stats.pierce)

	var label_text: String = "%s\nLv %d → %d" % [
		PosUpgrades.STAT_LABELS.get(stat, "?"), cur, cur + 1
	]
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.6, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 0.6, 1))
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	_style_button(btn, color)

	if not PosUpgrades.can_upgrade(pos, stat):
		btn.disabled = true
		btn.text = "%s\nMAX" % PosUpgrades.STAT_LABELS.get(stat, "?")

	btn.mouse_entered.connect(func(): AudioManager.play_sfx("button", 0.1, -14.0))
	btn.pressed.connect(_on_stat_pressed.bind(stat))
	return btn

func _on_stat_pressed(stat: int) -> void:
	if _locked:
		return
	_locked = true
	AudioManager.play_sfx("levelup")
	var pos := _chosen_pos
	hide_panel()
	result_chosen.emit(pos, stat)

# ---------- helpers ----------

func _clear_row() -> void:
	for c in row.get_children():
		c.queue_free()

func _grab_first_enabled() -> void:
	for c in row.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus()
			return

func _style_button(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.14, 0.98)
	normal.border_color = color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hover := normal.duplicate()
	hover.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1.0)
	hover.border_color = Color(1, 1, 1, 1)
	hover.set_border_width_all(4)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	disabled.border_color = Color(0.3, 0.3, 0.35, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

# ---------- keyboard shortcuts ----------

func _unhandled_key_input(event: InputEvent) -> void:
	if not root_panel.visible or _locked:
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
	if idx >= 0 and idx < row.get_child_count():
		var btn: Button = row.get_child(idx)
		if not btn.disabled:
			btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()
