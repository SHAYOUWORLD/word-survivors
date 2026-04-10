extends Node2D
## Floating damage / feedback number above an enemy.

@onready var label: Label = $Label

func setup_normal(amount: int) -> void:
	_apply(str(amount), Color(1.0, 1.0, 1.0, 0.9), 18, 28.0, 0.5)

func setup_strong(amount: int, color: Color) -> void:
	_apply(str(amount), color, 26, 40.0, 0.7)

func _apply(text: String, color: Color, font_size: int, rise: float, duration: float) -> void:
	if is_node_ready():
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
		label.modulate = color
	else:
		call_deferred("_apply_deferred", text, color, font_size)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - rise, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", position.x + randf_range(-10, 10), duration)
	tw.tween_property(self, "modulate:a", 0.0, duration).set_delay(duration * 0.5)
	tw.chain().tween_callback(queue_free)

func _apply_deferred(text: String, color: Color, font_size: int) -> void:
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
