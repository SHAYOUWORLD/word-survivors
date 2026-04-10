extends CanvasLayer
## Massive centered "english ＝ japanese" callout for critical hits. This is
## the single most important visual in the PoC — it is the dopamine moment
## that should also burn the word pair into memory.

@onready var label_root: Control = $Root
@onready var en_label: Label = $Root/VBox/EN
@onready var eq_label: Label = $Root/VBox/EQ
@onready var ja_label: Label = $Root/VBox/JA
@onready var flash_rect: ColorRect = $Root/Flash

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	label_root.modulate.a = 0.0
	flash_rect.modulate.a = 0.0

func show_pair(english: String, japanese: String, pos_color: Color, word_id: String = "") -> void:
	en_label.text = english
	ja_label.text = japanese
	en_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	ja_label.add_theme_color_override("font_color", pos_color)
	eq_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))

	# Multimodal: fire the pronunciation alongside the visual reveal. If the
	# voice file doesn't exist, AudioManager silently no-ops.
	if word_id != "":
		AudioManager.play_voice(word_id)

	# White flash
	flash_rect.modulate.a = 1.0
	var ftw := create_tween()
	ftw.tween_property(flash_rect, "modulate:a", 0.0, 0.15)

	# Text rises + scales in, then fades out
	label_root.scale = Vector2(0.8, 0.8)
	label_root.modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label_root, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(label_root, "scale", Vector2(1.0, 1.0), 0.12)
	tw.chain().tween_interval(0.4)
	tw.chain().tween_property(label_root, "modulate:a", 0.0, 0.35)
