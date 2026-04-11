extends Node2D
## Floating popup shown at an enemy's death position during PHASE_A kills 1..3.
## Displays english → japanese, dots indicating kill progress (●●○ etc.), and
## fires the word's pronunciation through AudioManager.

@onready var bg: ColorRect = $BG
@onready var en_label: Label = $EN
@onready var ja_label: Label = $JA
@onready var dots_label: Label = $KillDots

func setup(word: Dictionary, kill_count: int) -> void:
	var en: String = word.get("english", "?")
	var ja: String = word.get("japanese", "?")
	var pos: String = word.get("pos", "noun")
	var color: Color = WordDatabase.get_pos_color(pos)
	if is_node_ready():
		_apply(en, ja, color, kill_count, word.get("id", ""))
	else:
		call_deferred("_apply", en, ja, color, kill_count, word.get("id", ""))

func _apply(en: String, ja: String, color: Color, kill_count: int, word_id: String) -> void:
	en_label.text = en
	en_label.add_theme_color_override("font_color", color)
	ja_label.text = ja
	dots_label.text = _build_dots(kill_count)
	bg.color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.88)

	# Multimodal: pronunciation audio alongside the visual reveal.
	if word_id != "":
		AudioManager.play_voice(word_id)

	# Keep the popup on screen long enough to read (~1.4s), floating up and
	# fading out at the end.
	var rise := create_tween()
	rise.tween_property(self, "position:y", position.y - 60, 1.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var fade := create_tween()
	fade.tween_interval(1.0)
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)

static func _build_dots(kill_count: int) -> String:
	# kill_count is 1..3 here.
	var out: String = ""
	for i in range(3):
		if i < kill_count:
			out += "●"
		else:
			out += "○"
		if i < 2:
			out += " "
	return out
