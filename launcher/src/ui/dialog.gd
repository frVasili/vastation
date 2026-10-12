class_name Dialog
extends Control
## Modal glass dialog: title, message, 1-2 buttons. d-pad left/right + confirm, or touch.

signal chosen(index: int)

var buttons: Array[String] = []
var cancel_index := 0
var focus := 0
var _panel: GlassPanel
var _btn_rects: Array[Rect2] = []
var _title: LabelLine
var _msg: Label
var _done := false

func setup(title: String, message: String, labels: Array[String], default_focus: int, cancel_idx: int) -> void:
	buttons = labels
	focus = default_focus
	cancel_index = cancel_idx
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var pw := 760.0
	var rx := RegEx.new()
	rx.compile("\\s+")
	message = rx.sub(message, " ", true).strip_edges()
	var mf := Fx.font(500, 0)
	var mh := mf.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, pw - 96.0, 26, 4).y
	mh = minf(mh, mf.get_height(26) * 4.0)
	var ph := maxf(112.0 + mh + 38.0 + 64.0 + 38.0, 300.0)
	_panel = GlassPanel.new(Vector2(pw, ph), 30.0)
	add_child(_panel)
	_title = LabelLine.make(title, 44, 800, Pal.text, 1)
	_title.box_w = pw - 96.0
	_title.position = Vector2(48, 38)
	_panel.add_child(_title)
	_msg = Label.new()
	_msg.text = message
	_msg.add_theme_font_override("font", mf)
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", Color(Pal.text, 0.88))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.max_lines_visible = 4
	_msg.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.position = Vector2(48, 112)
	_msg.size = Vector2(pw - 96.0, mh + 4.0)
	_panel.add_child(_msg)
	var bw := 250.0
	var total := bw * buttons.size() + 28.0 * (buttons.size() - 1)
	for i in buttons.size():
		_btn_rects.append(Rect2((pw - total) * 0.5 + i * (bw + 28.0), ph - 64.0 - 38.0, bw, 64.0))
	_panel.resized.connect(queue_redraw)
	var draw := Control.new()
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.size = Vector2(pw, ph)
	draw.draw.connect(func() -> void: _draw_buttons(draw))
	_panel.add_child(draw)
	_draw_node = draw

var _draw_node: Control

func _draw_buttons(c: Control) -> void:
	var f := Fx.font(700, 2)
	for i in _btn_rects.size():
		var r := _btn_rects[i]
		var on := i == focus
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.blue.lerp(Pal.cyan, 0.25), 0.95) if on else Color(1, 1, 1, 0.12)
		sb.set_corner_radius_all(32)
		sb.anti_aliasing = true
		if on:
			sb.shadow_color = Color(Pal.cyan, 0.35)
			sb.shadow_size = 14
		c.draw_style_box(sb, r)
		var label := buttons[i].to_upper()
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		c.draw_string(f, Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + 32 + (f.get_ascent(28) - f.get_descent(28)) * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

func open() -> void:
	resized.connect(func() -> void: _panel.position = (size - _panel.size) * 0.5)
	_panel.position = (size - _panel.size) * 0.5
	modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Perf.kick(0.6)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.05, 0.62))

func do_action(action: String) -> void:
	if _done:
		return
	match action:
		"ui_left":
			if focus > 0:
				focus -= 1
				Sfx.play("nav")
				_draw_node.queue_redraw()
		"ui_right":
			if focus < buttons.size() - 1:
				focus += 1
				Sfx.play("nav")
				_draw_node.queue_redraw()
		"confirm": _finish(focus)
		"cancel": _finish(cancel_index)

func _finish(i: int) -> void:
	_done = true
	Sfx.play("select" if i != cancel_index else "back")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		chosen.emit(i)
		queue_free())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var p := mb.position - _panel.position
			for i in _btn_rects.size():
				if _btn_rects[i].grow(6.0).has_point(p):
					focus = i
					_draw_node.queue_redraw()
					do_action("confirm")
					return
