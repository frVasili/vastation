class_name BottomBar
extends Control
## Button hints (also touch buttons) on the left, "2 / 5" position on the right.

signal pressed(action: String)

const MARGIN := 48.0
const PILL_H := 40.0
const LABEL_PX := 24
var show_stop := false:
	set(v):
		show_stop = v
		_relayout()
var pos_text := ""
var _items: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_relayout)
	_relayout()

func set_position_text(t: String) -> void:
	pos_text = t
	queue_redraw()

func _glyph_w(g: String) -> float:
	return PILL_H if g.length() == 1 else Fx.text_width(g, 800, 0, 22) + 28.0

func _relayout() -> void:
	_items.clear()
	var defs: Array[Dictionary] = [
		{"g": "A", "label": "Start", "action": "confirm", "col": Color("48d36b")},
		{"g": "B", "label": "Back", "action": "cancel", "col": Color("ff5f73")},
		{"g": "LB", "label": "", "action": "tab_prev", "col": Color(1, 1, 1, 0.3)},
		{"g": "RB", "label": "Category", "action": "tab_next", "col": Color(1, 1, 1, 0.3)},
	]
	if show_stop:
		defs.append({"g": "Y", "label": "Stop", "action": "options", "col": Color("ffcf3d")})
	var x := MARGIN
	var cy := size.y - MARGIN - PILL_H * 0.5
	for d in defs:
		var gw := _glyph_w(str(d["g"]))
		var lw := Fx.text_width(str(d["label"]), 600, 0, LABEL_PX)
		var w := gw + (12.0 + lw if str(d["label"]) != "" else 0.0)
		d["gx"] = x
		d["gw"] = gw
		d["w"] = w
		var hit := Rect2(x - 8.0, cy - 32.0, maxf(w + 16.0, 64.0), 64.0)
		d["hit"] = hit
		_items.append(d)
		var is_lb := str(d["g"]) == "LB"
		x += w + (10.0 if is_lb else 38.0)
	queue_redraw()

func _draw() -> void:
	var cy := size.y - MARGIN - PILL_H * 0.5
	var f := Fx.font(600, 0)
	for d in _items:
		var gx := float(d["gx"])
		var gw := float(d["gw"])
		var g := str(d["g"])
		var col: Color = d["col"]
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(PILL_H * 0.5))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(gx, cy - PILL_H * 0.5, gw, PILL_H))
		var gf := Fx.font(800, 0)
		var tw := gf.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var tcol := Color(0.03, 0.05, 0.14) if g.length() == 1 else Color.WHITE
		draw_string(gf, Vector2(gx + (gw - tw) * 0.5, cy + (gf.get_ascent(22) - gf.get_descent(22)) * 0.5), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tcol)
		var label := str(d["label"])
		if label != "":
			draw_string(f, Vector2(gx + gw + 12.0, cy + (f.get_ascent(LABEL_PX) - f.get_descent(LABEL_PX)) * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX, Color(Pal.text, 0.92))
	if pos_text != "":
		var pf := Fx.font(700, 1)
		var w := pf.get_string_size(pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(pf, Vector2(size.x - MARGIN - w, cy + (pf.get_ascent(28) - pf.get_descent(28)) * 0.5), pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Pal.text, 0.85))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for d in _items:
				if (d["hit"] as Rect2).has_point(mb.position):
					pressed.emit(str(d["action"]))
					return
