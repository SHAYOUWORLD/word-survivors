extends CanvasLayer
## HUD: HP bar (top-left), timer (top-center), kills (top-right),
## next-bullet queue + held-word slot strip (bottom).

const NEXT_QUEUE_COUNT := 3

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

func bind_player(p: Node2D) -> void:
	_player = p
	p.hp_changed.connect(_on_hp_changed)
	var bs: Node = p.get_node("BulletSystem")
	if bs:
		bs.slots_changed.connect(_refresh_slots)
		bs.slots_changed.connect(_refresh_next_queue)
		bs.fired.connect(_refresh_next_queue)
	_on_hp_changed(p.current_hp, p.MAX_HP)
	_refresh_slots()
	_refresh_next_queue()

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
	var total: int = WordDatabase.all_words.size()
	var mastered: int = MasteryTracker.mastered_count()
	kills_label.text = "マスター %d / %d" % [mastered, total]

func _refresh_slots() -> void:
	for c in slot_strip.get_children():
		c.queue_free()
	if _player == null:
		return
	var bs: Node = _player.get_node("BulletSystem")
	if bs == null:
		return
	for w in bs.held_words:
		var panel := _make_slot(w)
		slot_strip.add_child(panel)

func _refresh_next_queue() -> void:
	for c in next_queue.get_children():
		c.queue_free()
	if _player == null:
		return
	var bs: Node = _player.get_node("BulletSystem")
	if bs == null:
		return
	var upcoming: Array = bs.get_next_words(NEXT_QUEUE_COUNT)
	for i in upcoming.size():
		var item := _make_queue_item(upcoming[i], i == 0)
		next_queue.add_child(item)

func _make_queue_item(word: Dictionary, is_next: bool) -> Control:
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	sb.border_color = color
	var border: int = 4 if is_next else 2
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(8)
	var pad: int = 20 if is_next else 14
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	# pocv4: bullets are english-labeled now, so the queue preview matches.
	lbl.text = word.get("english", "")
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 36 if is_next else 26)
	panel.add_child(lbl)
	return panel

func _make_slot(word: Dictionary) -> Control:
	var color: Color = WordDatabase.get_pos_color(word.get("pos", "noun"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = word.get("english", "")
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 20)
	panel.add_child(lbl)
	return panel
