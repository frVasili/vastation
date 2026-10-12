class_name RunningPill
extends Control
## "RUNNING" status pill: green dot + bold text on dark glass.

const TXT := "RUNNING"
const PX := 22

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Fx.text_width(TXT, 800, 1, PX) + 52.0, 38.0)

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.03, 0.08, 0.72)
	sb.set_corner_radius_all(19)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	draw_circle(Vector2(20, 19), 14.0, Color(0.2, 1.0, 0.45, 0.22), true, -1.0, true)
	draw_circle(Vector2(20, 19), 7.0, Color(0.3, 1.0, 0.5), true, -1.0, true)
	var f := Fx.font(800, 1)
	draw_string(f, Vector2(38, 19 + (f.get_ascent(PX) - f.get_descent(PX)) * 0.5), TXT, HORIZONTAL_ALIGNMENT_LEFT, -1, PX, Color(0.92, 1.0, 0.95))
