extends CanvasLayer
## HUD: HP bar (top-left), timer (top-center), quiz-progress kill counter
## (top-right), and a bottom-center strip showing the 2 Japanese bullet
## words with the active one highlighted. TAB (handled by BulletSystem)
## switches the active word.

@onready var hp_bar: ProgressBar = $Root/TopLeft/HPPanel/HPBar
@onready var hp_label: Label = $Root/TopLeft/HPPanel/HPBar/HPLabel
@onready var time_label: Label = $Root/TopCenter/TimeLabel
@onready var kills_label: Label = $Root/TopRight/KillsLabel
@onready var next_queue: HBoxContainer = $Root/BottomCenter/NextQueue
@onready var slot_strip: HBoxContainer = $Root/BottomCenter/Strip

var _player: Node2D = null

func _ready() -> void:
	_style_bars()
	GameManager.run_time_updated.connect(_on_time_updated)
	GameManager.kills_changed.connect(_on_kills_changed)
	_on_kills_changed(0, 0)

func bind_player(p: Node2D) -> void:
	_player = p
	p.hp_changed.connect(_on_hp_changed)
	var bs: Node = p.get_node("BulletSystem")
	if bs:
		bs.slots_changed.connect(_refresh_slots)
		bs.active_changed.connect(_refresh_slots)
	_on_hp_changed(p.current_hp, p.MAX_HP)
	_refresh_slots()
	# The old "next queue" is repurposed as a TAB hint.
	_set_hint_text()

func _style_bars() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	bg.border_color = Color(1.0, 0.85, 0.3, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.25, 0.3, 1.0)
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill)

func _on_hp_changed(cur: int, maxv: int) -> void:
	hp_bar.max_value = maxv
	hp_bar.value = cur
	hp_label.text = "%d / %d" % [cur, maxv]

func _on_time_updated(_t: float) -> void:
	time_label.text = GameManager.format_time(GameManager.run_time)

func _on_kills_changed(_total: int, since_quiz: int) -> void:
	kills_label.text = "次のクイズまで %d / %d" % [since_quiz, GameManager.KILLS_PER_QUIZ]

func _set_hint_text() -> void:
	for c in next_queue.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "[TAB] で弾を切り替え"
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 22)
	next_queue.add_child(lbl)

func _refresh_slots() -> void:
	for c in slot_strip.get_children():
		c.queue_free()
	if _player == null:
		return
	var bs: Node = _player.get_node("BulletSystem")
	if bs == null:
		return
	var group_size: int = bs.GROUP_SIZE
	var active_group: int = bs.active_group
	for i in bs.slots.size():
		# Insert a thin separator between the two groups so the player can see
		# the TAB boundary (noun+verb | adjective+adverb).
		if i > 0 and i % group_size == 0:
			slot_strip.add_child(_make_group_divider())
		var is_active: bool = (i / group_size) == active_group
		var panel := _make_slot(bs.slots[i], is_active)
		slot_strip.add_child(panel)

func _make_slot(word: Dictionary, is_active: bool) -> Control:
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95) if is_active else Color(0.05, 0.05, 0.08, 0.75)
	sb.border_color = color if is_active else Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	sb.set_border_width_all(5 if is_active else 2)
	sb.set_corner_radius_all(10)
	var pad: int = 24 if is_active else 14
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var ja_lbl := Label.new()
	ja_lbl.text = word.get("japanese", "")
	ja_lbl.add_theme_color_override("font_color", color if is_active else Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 1.0))
	ja_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ja_lbl.add_theme_constant_override("outline_size", 4)
	ja_lbl.add_theme_font_size_override("font_size", 44 if is_active else 30)
	ja_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ja_lbl)
	panel.add_child(vbox)
	return panel

func _make_group_divider() -> Control:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(4, 80)
	sep.color = Color(1, 0.9, 0.6, 0.6)
	return sep
