class_name LabelLine
extends Control
## One line of text drawn with the launcher font. Size = text extent; align applies when `box_w` > 0.

var text := "":
	set(v):
		text = v
		_refit()
var px := 28:
	set(v):
		px = v
		_refit()
var weight := 500:
	set(v):
		weight = v
		_refit()
var spacing := 0:
	set(v):
		spacing = v
		_refit()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var shadow := true
## When > 0 the text shrinks (down to 24 px) to fit this width and is aligned inside it.
var box_w := 0.0:
	set(v):
		box_w = v
		_refit()
var align := HORIZONTAL_ALIGNMENT_LEFT:
	set(v):
		align = v
		queue_redraw()
var _draw_px := 28

static func make(t: String, size_px: int, w: int, col: Color = Color.WHITE, sp: int = 0) -> LabelLine:
	var l := LabelLine.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.px = size_px
	l.weight = w
	l.spacing = sp
	l.color = col
	l.text = t
	return l

func _refit() -> void:
	_draw_px = Fx.fit_size(text, weight, spacing, px, box_w)
	var f := Fx.font(weight, spacing)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _draw_px).x
	custom_minimum_size = Vector2(box_w if box_w > 0.0 else w, f.get_height(_draw_px))
	size = custom_minimum_size
	queue_redraw()

func text_w() -> float:
	return Fx.text_width(text, weight, spacing, _draw_px)

func _draw() -> void:
	var f := Fx.font(weight, spacing)
	var asc := f.get_ascent(_draw_px)
	var x := 0.0
	if box_w > 0.0:
		var w := text_w()
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x = (box_w - w) * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x = box_w - w
	if shadow:
		draw_string(f, Vector2(x, asc + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _draw_px, Color(0, 0, 0.05, 0.4 * color.a))
	draw_string(f, Vector2(x, asc), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _draw_px, color)
