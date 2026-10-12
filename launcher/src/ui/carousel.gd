class_name Carousel
extends Control
## The tile rows. Owns the current row, category slide transitions and mouse/touch (click, drag + inertia).

signal focus_changed(tile: Dictionary, index: int, count: int)
signal activated(tile: Dictionary)

const ANCHOR_X := 0.3
const ANCHOR_Y := 0.425
var row: Row
var _old: Row
var _memory := {}  # category id -> focused index
var _cat_id := ""
var _running: Array[String] = []
var _press := Vector2.ZERO
var _pressing := false
var _dragging := false
var _drag_start_scroll := 0.0
var _vel := 0.0
var _last_x := 0.0
var _last_t := 0.0
var _clock := 0.0
var _paused := false
var _trans: Tween
var _press_idx := -1
var _press_focus := -1
var _exceeded := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	resized.connect(_reanchor)

func anchor_point() -> Vector2:
	return Vector2(size.x * ANCHOR_X, size.y * ANCHOR_Y)

func _reanchor() -> void:
	for r: Row in [row, _old]:
		if r != null:
			r.anchor = anchor_point()
			r.size = size

func current_tile() -> Dictionary:
	if row == null or row.tiles.is_empty():
		return {}
	return row.tiles[row.index]

func count() -> int:
	return 0 if row == null else row.tiles.size()

func set_running(ids: Array[String]) -> void:
	_running = ids
	if row:
		row.set_running(ids)

## Show a category. dir: +1 = next (old row up, new from below), -1 = previous, 0 = no animation.
func show_category(cat_id: String, items: Array[Dictionary], dir: int) -> void:
	if row != null:
		_memory[_cat_id] = row.index
	var new_row := Row.new()
	new_row.size = size
	new_row.anchor = anchor_point()
	add_child(new_row)
	new_row.build(items, _running)
	new_row.index_changed.connect(_on_index_changed)
	var start: int = clampi(int(_memory.get(cat_id, 0)), 0, maxi(items.size() - 1, 0))
	new_row.index = start
	new_row.scroll = float(start)
	# a transition still running is superseded: end it cleanly (exactly one outgoing row at a time)
	if _trans:
		_trans.kill()
		_trans = null
	if _old != null:
		_old.queue_free()
		_old = null
	var prev := row
	row = new_row
	_cat_id = cat_id
	new_row.layout(_clock)
	if dir == 0 or prev == null:
		if prev:
			prev.queue_free()
	else:
		_old = prev
		_old.stop_tweens()
		var off := 130.0 * dir
		var out_row := _old
		var tw := create_tween().set_parallel(true)
		_trans = tw
		tw.tween_property(_old, "position:y", -off, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_old, "modulate:a", 0.0, 0.28)
		new_row.position.y = off
		new_row.modulate.a = 0.0
		tw.tween_property(new_row, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(new_row, "modulate:a", 1.0, 0.3)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(out_row):
				out_row.queue_free()
			if _old == out_row:
				_old = null
			_trans = null)
		Perf.kick(0.7)
	_emit_focus()

func _emit_focus() -> void:
	focus_changed.emit(current_tile(), row.index, row.tiles.size())

func _on_index_changed(_i: int) -> void:
	Sfx.play("nav")
	_emit_focus()

func step(d: int) -> void:
	if row:
		row.step(d)

func nudge_vertical(dir: int) -> void:
	if row == null:
		return
	var tw := create_tween()
	tw.tween_property(row, "position:y", -dir * 14.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Perf.kick(0.5)

func jump_to(i: int) -> void:
	if row:
		row.go_to(i)

func relayout() -> void:
	if row:
		row.layout(_clock)

func set_paused(p: bool) -> void:
	_paused = p

func _process(delta: float) -> void:
	if _paused:
		return
	_clock += delta
	if row:
		row.layout(_clock)
	if _old:
		_old.layout(_clock)

# --- mouse / touch -------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if row == null or _paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_dragging = false
			_exceeded = false
			_press = mb.position
			_press_idx = row.tile_at(mb.position - row.position)
			_press_focus = row.index
			_drag_start_scroll = row.scroll
			_vel = 0.0
			_last_x = mb.position.x
			_last_t = Time.get_ticks_msec() / 1000.0
			row.stop_tweens()
			row.over = 0.0
		elif _pressing:
			_pressing = false
			if _dragging:
				_release_drag()
			elif not _exceeded:
				_click(mb.position)
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if (mm.position - _press).length() > 14.0:
			_exceeded = true
		if not _dragging and absf(mm.position.x - _press.x) > 14.0:
			_dragging = true
		if _dragging:
			var now := Time.get_ticks_msec() / 1000.0
			var dt := maxf(now - _last_t, 0.001)
			_vel = lerpf(_vel, (mm.position.x - _last_x) / dt, 0.4)
			_last_x = mm.position.x
			_last_t = now
			var raw := _drag_start_scroll - (mm.position.x - _press.x) / row.pitch()
			var maxs := row.nodes.size() - 1.0
			row.scroll = raw
			row.over = (clampf(raw, 0.0, maxs) - raw) * row.pitch() * -0.35
			var nearest := clampi(roundi(raw), 0, row.nodes.size() - 1)
			if nearest != row.index:
				row.index = nearest
				_on_index_changed(nearest)
			Perf.kick(0.5)

func _release_drag() -> void:
	var target := row.scroll - _vel / row.pitch() * 0.25
	var i := clampi(roundi(target), 0, row.nodes.size() - 1)
	var ov := row.over
	row.over = 0.0
	if absf(ov) > 0.5:
		var tw := create_tween()
		row.over = ov
		tw.tween_property(row, "over", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	row.go_to(i, 0.35)

func _click(p: Vector2) -> void:
	var i := row.tile_at(p - row.position)
	if i < 0 or i != _press_idx:
		return
	if i == _press_focus and i == row.index:
		activated.emit(current_tile())
	else:
		row.go_to(i)
