class_name Home
extends Control
## The home screen: top bar, carousel, title block, bottom bar. Knows nothing about launching.

signal activated(tile: Dictionary)
signal stop_requested(tile: Dictionary)
signal focus_changed(tile: Dictionary)

var catalog: Catalog
var backend: LauncherBackend
var cat_index := 0
var top := TopBar.new()
var carousel := Carousel.new()
var info := InfoBlock.new()
var bottom := BottomBar.new()
var _tile: Dictionary = {}
var _first := true
var _notice := ""

func setup(cat: Catalog, be: LauncherBackend) -> void:
	catalog = cat
	backend = be

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	carousel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(carousel)
	add_child(info)
	top.anchor_right = 1.0
	top.offset_bottom = 150.0
	add_child(top)
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -130.0
	add_child(bottom)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titles: Array[String] = []
	for c in catalog.categories:
		titles.append(str(c["title"]))
	top.set_titles(titles)
	_notice = catalog.notice
	if _notice != "":
		get_tree().create_timer(15.0).timeout.connect(_dismiss_notice)
	carousel.focus_changed.connect(_on_focus)
	carousel.activated.connect(func(t: Dictionary) -> void: activated.emit(t))
	top.tab_pressed.connect(func(i: int) -> void:
		_dismiss_notice()
		set_category(i))
	bottom.pressed.connect(do_action)
	backend.state_changed.connect(refresh_state)
	resized.connect(_on_resized)
	_on_resized()
	carousel.set_running(backend.running_ids())
	_show_category(0, 0)

func _on_resized() -> void:
	info.margin_left = size.x * Carousel.ANCHOR_X - 172.0
	# title block sits under the carousel: baseline math relative to the carousel centre
	info.position = Vector2(0, size.y * Carousel.ANCHOR_Y + Catalog.BASE_H * 0.5 * Row.BIG + 24.0)
	info.size = Vector2(size.x, 160)

func _show_category(i: int, dir: int) -> void:
	cat_index = i
	var c := catalog.categories[i]
	carousel.show_category(str(c["id"]), catalog.tiles_in(str(c["id"])), dir)
	top.set_active(i, dir != 0)

func set_category(i: int) -> void:
	if i == cat_index or i < 0 or i >= catalog.categories.size():
		return
	Sfx.play("tab")
	_show_category(i, 1 if i > cat_index else -1)

func _on_focus(tile: Dictionary, index: int, count: int) -> void:
	var changed := tile != _tile
	_tile = tile
	if not tile.is_empty():
		info.show_tile(tile, not _first and changed)
		_first = false
		bottom.set_position_text("%d / %d" % [index + 1, count])
		top.set_accent((tile["color_b"] as Color).lerp(Pal.cyan, 0.3))
		bottom.show_stop = str(tile.get("id", "")) in backend.running_ids()
		focus_changed.emit(tile)

func refresh_state() -> void:
	carousel.set_running(backend.running_ids())
	if not _tile.is_empty():
		bottom.show_stop = str(_tile.get("id", "")) in backend.running_ids()
	var st := backend.status_text()
	if st == "" and _notice != "":
		st = _notice if _notice.length() <= 46 else _notice.substr(0, 45) + "..."
	top.set_status(st)

func _dismiss_notice() -> void:
	if _notice != "":
		_notice = ""
		catalog.notice = ""
		refresh_state()

## UI actions from controller, keyboard or touch buttons.
func do_action(action: String) -> void:
	Perf.input()
	_dismiss_notice()
	match action:
		"ui_left": carousel.step(-1)
		"ui_right": carousel.step(1)
		"ui_up": _tab(-1)
		"ui_down": _tab(1)
		"tab_prev": _tab(-1)
		"tab_next": _tab(1)
		"confirm":
			if not _tile.is_empty():
				activated.emit(_tile)
		"cancel":
			if carousel.row and carousel.row.index > 0:
				Sfx.play("back")
				carousel.jump_to(0)
		"options":
			if not _tile.is_empty() and str(_tile.get("id", "")) in backend.running_ids():
				Sfx.play("select")
				stop_requested.emit(_tile)

func _tab(d: int) -> void:
	var n := cat_index + d
	if n < 0 or n >= catalog.categories.size():
		carousel.nudge_vertical(d)
		return
	set_category(n)

## Focus a tile immediately (no animation), switching category if needed.
func focus_tile(tile: Dictionary) -> void:
	for i in catalog.categories.size():
		if str(catalog.categories[i]["id"]) == str(tile.get("category", "")):
			if i != cat_index:
				_show_category(i, 0)
			var idx := carousel.row.tiles.find(tile)
			if idx >= 0:
				carousel.row.go_to(idx, 0.0)
			carousel.relayout()
			return

func focused_tile() -> Dictionary:
	return _tile

func focused_global_center() -> Vector2:
	var row := carousel.row
	if row == null:
		return size * 0.5
	var t := row.nodes[row.index]
	return t.get_global_transform() * (t.size * 0.5)
