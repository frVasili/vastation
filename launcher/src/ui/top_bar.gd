class_name TopBar
extends Control
## Category tabs (left) and clock / date / status (right). Everything inside the safe margin.

signal tab_pressed(index: int)

const MARGIN := 48.0
const TAB_PX := 34
const GAP := 52.0
var titles: Array[String] = []
var active := 0
var accent := Color("2f7fd6")
var status := ""
var clock_text := "00:00"
var date_text := ""
var frozen := false
var _rects: Array[Rect2] = []
var _bar_x := 0.0:
	set(v):
		_bar_x = v
		_place_bar()
		queue_redraw()
var _bar_w := 0.0:
	set(v):
		_bar_w = v
		_place_bar()
		queue_redraw()
var _tween: Tween
var _last_min := -1
var _last_24 := true
var _last_ver := -1

const PAD := 26.0
var _ul := ColorRect.new()
var _ul_mat := ShaderMaterial.new()

func _place_bar() -> void:
	var y := MARGIN + Fx.font(700, 3).get_height(TAB_PX) + 8.0
	_ul.position = Vector2(_bar_x - PAD, y - PAD)
	_ul.size = Vector2(_bar_w + PAD * 2.0, 6.0 + PAD * 2.0)
	_ul_mat.set_shader_parameter("bar_size", Vector2(_bar_w, 6.0))
	_ul_mat.set_shader_parameter("bar_col", accent.lerp(Color.WHITE, 0.35))

func _ready() -> void:
	_ul_mat.shader = Fx.shader("bar")
	_ul_mat.set_shader_parameter("pad", PAD)
	_ul.material = _ul_mat
	_ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ul)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_relayout)

func set_titles(t: Array[String]) -> void:
	titles = t
	_relayout()

func _relayout() -> void:
	_rects.clear()
	var x := MARGIN
	var f := Fx.font(700, 3)
	for t in titles:
		var w := f.get_string_size(t.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_PX).x
		_rects.append(Rect2(x, MARGIN, w, f.get_height(TAB_PX)))
		x += w + GAP
	if active < _rects.size():
		_bar_x = _rects[active].position.x
		_bar_w = _rects[active].size.x
	_place_bar()
	queue_redraw()

func set_active(i: int, animate: bool = true) -> void:
	active = i
	if i >= _rects.size():
		return
	if _tween:
		_tween.kill()
	if not animate:
		_bar_x = _rects[i].position.x
		_bar_w = _rects[i].size.x
		queue_redraw()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_bar_x", _rects[i].position.x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_bar_w", _rects[i].size.x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Perf.kick(0.5)

func set_accent(c: Color) -> void:
	accent = c
	_place_bar()

func set_status(s: String) -> void:
	if s != status:
		status = s
		queue_redraw()

func _process(_d: float) -> void:
	if frozen:
		return
	Clock.tick()
	var dt := Clock.now()
	var m: int = dt["minute"]
	var h24 := Prefs.flag("clock_24h")
	if m != _last_min or h24 != _last_24 or Clock.version != _last_ver:
		_last_ver = Clock.version
		_last_min = m
		_last_24 = h24
		var hr: int = dt["hour"]
		if h24:
			clock_text = "%02d:%02d" % [hr, m]
		else:
			clock_text = "%d:%02d %s" % [(hr + 11) % 12 + 1, m, "PM" if hr >= 12 else "AM"]
		var days := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		date_text = "%s %d %s" % [days[dt["weekday"]], dt["day"], months[int(dt["month"]) - 1]]
		queue_redraw()

func _draw() -> void:
	var f := Fx.font(700, 3)
	for i in titles.size():
		var r := _rects[i]
		var on := i == active
		var col := Color(Pal.text, 1.0 if on else 0.45)
		draw_string(f, r.position + Vector2(1, f.get_ascent(TAB_PX) + 3), titles[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_PX, Color(0, 0, 0.05, 0.35 * col.a))
		draw_string(f, r.position + Vector2(0, f.get_ascent(TAB_PX)), titles[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_PX, col)
	# right side
	var cf := Fx.font(700, 1)
	var right := size.x - MARGIN
	var cw := cf.get_string_size(clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	draw_string(cf, Vector2(right - cw, MARGIN + cf.get_ascent(40)), clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.text)
	var df := Fx.font(500, 0)
	var dw := df.get_string_size(date_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var dy := MARGIN + cf.get_height(40) - 4.0
	draw_string(df, Vector2(right - dw, dy + df.get_ascent(24)), date_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.text, 0.7))
	if status != "":
		var sw := df.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(df, Vector2(right - sw, dy + df.get_height(24) + df.get_ascent(24)), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.cyan, 0.9))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				var hit := _rects[i].grow_individual(GAP * 0.5, 14.0, GAP * 0.5, 30.0)
				if hit.has_point(mb.position):
					tab_pressed.emit(i)
					return
