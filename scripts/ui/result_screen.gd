extends Control
## pocv5 post-run screen. The old version ran a second 4-choice quiz and
## showed correlation stats — all of that depended on the removed
## LearningTracker autoload. This trimmed version just shows the run summary
## (time + kills) and offers Retry/Quit.

@onready var title_label: Label = $Title
@onready var stats_label: Label = $Stats
@onready var summary_panel: PanelContainer = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/VBox/SummaryLabel
@onready var correlation_label: Label = $SummaryPanel/VBox/CorrelationLabel
@onready var per_word_list: VBoxContainer = $SummaryPanel/VBox/Scroll/List
@onready var retry_button: Button = $SummaryPanel/VBox/Buttons/RetryButton
@onready var quit_button: Button = $SummaryPanel/VBox/Buttons/QuitButton
@onready var quiz_root: PanelContainer = $QuizPanel

func _ready() -> void:
	_style_buttons()
	_populate_stats()
	AudioManager.play_bgm("title", 1.0)
	retry_button.pressed.connect(_on_retry)
	quit_button.pressed.connect(_on_quit)

	# The old "post-run quiz" panel is unused now — hide it and show the
	# summary immediately.
	quiz_root.visible = false
	summary_panel.visible = true
	_populate_summary()

func _populate_stats() -> void:
	title_label.text = "GAME OVER"
	title_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	stats_label.text = "プレイ時間: %s   |   撃破: %d" % [
		GameManager.format_time(GameManager.run_time),
		GameManager.kills,
	]

func _populate_summary() -> void:
	summary_label.text = "撃破数: %d" % GameManager.kills
	correlation_label.text = "もう一度挑戦してみよう！"
	for c in per_word_list.get_children():
		c.queue_free()

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

func _on_retry() -> void:
	AudioManager.play_sfx("button")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	AudioManager.play_sfx("button")
	get_tree().quit()
