class_name SettingsPanel
extends Control
## Glass panel sliding in from the right: volume, ambient, boot animation, theme, About.

signal theme_chosen(theme: String)
signal closed

const PW := 600.0
const ROW_H := 58.0
const TOP := 90.0
var backend: LauncherBackend
var focus := 0
var _panel: GlassPanel
var _list: Control
var _tween: Tween
var _rows: Array[String] = ["volume", "ambient", "boot", "clock", "zone", "theme"]
var _open := false

func setup(be: LauncherBackend) -> void:
	backend = be
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var ph := size.y - 96.0
	_panel = GlassPanel.new(Vector2(PW, ph), 30.0)
	add_child(_panel)
	_list = Control.new()
	_list.size = _panel.size
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.draw.connect(_draw_list)
	_panel.add_child(_list)
	resized.connect(_on_resized)

func _scrim_target() -> float:
	return 0.55

func _on_resized() -> void:
	if _open and _panel:
		_panel.resize(Vector2(PW, size.y - 96.0))
		_list.size = _panel.size
		_panel.position = Vector2(size.x - 48.0 - PW, 48)
		_list.queue_redraw()

func open() -> void:
	focus = 0
	_open = true
	visible = true
	_panel.resize(Vector2(PW, size.y - 96.0))
	_list.size = _panel.size
	_panel.position = Vector2(size.x, 48)
	modulate.a = 1.0
	_list.queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position:x", size.x - 48.0 - PW, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void: _scrim = v; queue_redraw(), 0.0, _scrim_target(), 0.3)
	Perf.kick(0.6)

var _scrim := 0.0

func close() -> void:
	if not _open:
		return
	_open = false
	Sfx.play("back")
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position:x", size.x, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_method(func(v: float) -> void: _scrim = v; queue_redraw(), _scrim, 0.0, 0.26)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())
	Perf.kick(0.6)

func is_open() -> bool:
	return _open

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.04, _scrim))

func _label(r: String) -> String:
	match r:
		"volume": return "Master volume"
		"ambient": return "Ambient music"
		"boot": return "Boot animation"
		"clock": return "Clock"
		"zone": return "Time zone"
		_: return "Theme"

func _value(r: String) -> String:
	match r:
		"volume": return "%d%%" % Prefs.volume()
		"ambient": return "ON" if Prefs.flag("ambient") else "OFF"
		"boot": return "ON" if Prefs.flag("boot_animation") else "OFF"
		"clock": return "24 h" if Prefs.flag("clock_24h") else "12 h"
		"zone": return Clock.label(Clock.zone())
		_: return _chosen_theme_label()

func _chosen_theme_label() -> String:
	var meta_name := ThemeStore.theme_title()
	return meta_name if meta_name != "" else ThemeStore.active.capitalize()

func refresh_theme() -> void:
	if _panel:
		_panel.refresh_theme()
	if _list:
		_list.queue_redraw()

func _draw_list() -> void:
	var c := _list
	var tf := Fx.font(800, 3)
	c.draw_string(tf, Vector2(40, 40 + tf.get_ascent(40)), "SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.text)
	var lf := Fx.font(600, 0)
	var vf := Fx.font(700, 1)
	for i in _rows.size():
		var y := TOP + i * ROW_H
		var r := Rect2(24, y, PW - 48.0, ROW_H - 6.0)
		if i == focus:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(Pal.blue, 0.55)
			sb.set_corner_radius_all(22)
			sb.anti_aliasing = true
			sb.border_color = Color(Pal.cyan, 0.8)
			sb.set_border_width_all(3)
			c.draw_style_box(sb, r)
		var cy := y + (ROW_H - 6.0) * 0.5
		c.draw_string(lf, Vector2(48, cy + (lf.get_ascent(28) - lf.get_descent(28)) * 0.5), _label(_rows[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.text)
		var v := _value(_rows[i])
		var vw := vf.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var vx := PW - 48.0 - 30.0 - vw
		c.draw_string(vf, Vector2(vx, cy + (vf.get_ascent(28) - vf.get_descent(28)) * 0.5), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.cyan.lerp(Color.WHITE, 0.3))
		if _rows[i] in ["volume", "zone", "theme"] and i == focus:
			c.draw_string(vf, Vector2(vx - 34, cy + (vf.get_ascent(28) - vf.get_descent(28)) * 0.5), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Pal.text, 0.6))
			c.draw_string(vf, Vector2(PW - 48.0 - 24.0, cy + (vf.get_ascent(28) - vf.get_descent(28)) * 0.5), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Pal.text, 0.6))
	var y0 := TOP + _rows.size() * ROW_H + 2.0
	c.draw_string(vf, Vector2(40, y0 + vf.get_ascent(24)), "ABOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.cyan, 0.9))
	var info: Dictionary = backend.session_info() if backend else {}
	var stream := "n/a"
	if not info.is_empty():
		stream = "%dx%d @ %d Hz" % [int(info.get("width", 0)), int(info.get("height", 0)), int(info.get("refresh", 0))]
	var lines: Array[String] = [
		"%s  v%s  -  Theme %s" % [ThemeStore.system_name(), str(ProjectSettings.get_setting("application/config/version", "0")), ThemeStore.theme_title()],
		"Stream  %s" % stream,
		"Apps pick up a new time zone the",
		"next time they start",
	]
	for k in lines.size():
		c.draw_string(lf, Vector2(40, y0 + 32 + k * 26 + lf.get_ascent(24)), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.text, 0.78 if k < 2 else 0.55))

func do_action(action: String) -> void:
	if not _open:
		return
	match action:
		"ui_up":
			_move(-1)
		"ui_down":
			_move(1)
		"ui_left": _adjust(-1)
		"ui_right": _adjust(1)
		"confirm": _adjust(1)
		"cancel", "options": close()

func _move(d: int) -> void:
	var n := clampi(focus + d, 0, _rows.size() - 1)
	if n != focus:
		focus = n
		Sfx.play("nav")
		_list.queue_redraw()

func _adjust(d: int) -> void:
	match _rows[focus]:
		"volume":
			var v := clampi(Prefs.volume() + d * 10, 0, 100)
			if v == Prefs.volume() and d != 0:
				if d > 0:
					v = 0  # confirm on max wraps to 0
				else:
					return
			Prefs.put("volume", v)
			Sfx.inst.apply_volume()
			Sfx.play("nav")
		"ambient":
			Prefs.put("ambient", not Prefs.flag("ambient"))
			Sfx.ambient(true, 1.0)
			Sfx.play("select")
		"boot":
			Prefs.put("boot_animation", not Prefs.flag("boot_animation"))
			Sfx.play("select")
		"clock":
			Prefs.put("clock_24h", not Prefs.flag("clock_24h"))
			Sfx.play("select")
		"zone":
			var z := Clock.cycled(Clock.zone(), d if d != 0 else 1)
			Prefs.put("timezone", z)
			Clock.apply(z)
			Sfx.play("nav")
		"theme":
			var all := ThemeStore.available()
			var cur_i := all.find(ThemeStore.active)
			var nxt := all[posmod(cur_i + (d if d != 0 else 1), all.size())]
			Prefs.put("theme", nxt)
			Sfx.play("select")
			theme_chosen.emit(nxt)
	_list.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _open or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := mb.position - _panel.position
	if not Rect2(Vector2.ZERO, _panel.size).has_point(p):
		close()
		return
	for i in _rows.size():
		if Rect2(24, TOP + i * ROW_H, PW - 48.0, ROW_H - 6.0).has_point(p):
			focus = i
			if _rows[i] in ["volume", "zone", "theme"]:
				_adjust(-1 if p.x < PW * 0.5 + 60.0 else 1)
			else:
				_adjust(1)
			return
