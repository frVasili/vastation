class_name Row
extends Control
## One horizontal row of tiles for a category. `scroll` is the (fractional) index sitting at the focus anchor.

signal index_changed(index: int)

const GAP := 30.0
const SMALL := 0.9
const BIG := 1.15
var tiles: Array[Dictionary] = []
var nodes: Array[Tile] = []
var index := 0
var anchor := Vector2(384, 320)
var scroll := 0.0:
	set(v):
		scroll = clampf(v, 0.0, maxf(nodes.size() - 1.0, 0.0))
var over := 0.0  # pixel offset for rubber-band / overscroll
var _prefix: Array[float] = []
var _scroll_tween: Tween
var _nudge_tween: Tween
var _t := 0.0
var _top := -1

func build(items: Array[Dictionary], running: Array[String]) -> void:
	tiles = items
	var acc := 0.0
	for t in tiles:
		var tile := Tile.new()
		tile.setup(t)
		tile.visible = false
		add_child(tile)
		nodes.append(tile)
		_prefix.append(acc)
		acc += float(t["w"]) * SMALL + GAP
	set_running(running)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_running(ids: Array[String]) -> void:
	for tile in nodes:
		tile.set_running(str(tile.data.get("id", "")) in ids)

func _center(i: int, k0: int, k1: int, e0: float, e1: float) -> float:
	var c := _prefix[i] + float(tiles[i]["w"]) * SMALL * 0.5
	if i > k0:
		c += e0
	if i > k1:
		c += e1
	if i == k0:
		c += e0 * 0.5
	if i == k1 and k1 != k0:
		c += e1 * 0.5
	return c

func layout(time_s: float) -> void:
	var n := nodes.size()
	if n == 0:
		return
	_t = time_s
	var k0 := clampi(floori(scroll), 0, n - 1)
	var k1 := mini(k0 + 1, n - 1)
	var fr := scroll - float(k0)
	var e0 := float(tiles[k0]["w"]) * (lerpf(SMALL, BIG, clampf(1.0 - fr, 0.0, 1.0)) - SMALL)
	var e1 := 0.0 if k1 == k0 else float(tiles[k1]["w"]) * (lerpf(SMALL, BIG, clampf(fr, 0.0, 1.0)) - SMALL)
	var cf := lerpf(_center(k0, k0, k1, e0, e1), _center(k1, k0, k1, e0, e1), fr)
	var pulse := 0.5 + 0.5 * sin(time_s * TAU / 2.4)
	var lo := maxi(k0 - 12, 0)
	var hi := mini(k1 + 12, n - 1)
	for i in n:
		var tile := nodes[i]
		if i < lo or i > hi:
			tile.visible = false
			continue
		var f := clampf(1.0 - absf(float(i) - scroll), 0.0, 1.0)
		var cx := anchor.x + (_center(i, k0, k1, e0, e1) - cf) + over
		var tw := float(tiles[i]["w"])
		var sc := lerpf(SMALL, BIG, f)
		var half := tw * sc * 0.5
		var on_screen := cx + half > -40.0 and cx - half < size.x + 40.0
		tile.visible = on_screen
		if not on_screen:
			continue
		tile.apply_focus(f, pulse)
		var bob := sin(time_s * 1.3) * 4.0 * f
		tile.position = Vector2(cx - tw * 0.5, anchor.y - Catalog.BASE_H * 0.5 + bob)
		if f > 0.5 and _top != i:
			_top = i
			move_child(tile, -1)
		# fade near the screen edges
		var right_fade := clampf((size.x - 24.0 - (cx - half)) / (tw * 0.6), 0.0, 1.0)
		var left_fade := clampf((cx + half - 24.0) / (tw * 0.6), 0.0, 1.0)
		tile.modulate.a = minf(right_fade, left_fade)

## Pixels of scroll per tile step around the focus (for drags).
func pitch() -> float:
	var i := clampi(roundi(scroll), 0, maxi(nodes.size() - 1, 0))
	return float(tiles[i]["w"]) * SMALL + GAP + 20.0 if not tiles.is_empty() else 300.0

func tile_at(local: Vector2) -> int:
	for i in range(nodes.size() - 1, -1, -1):
		var tile := nodes[i]
		if not tile.visible:
			continue
		var r := Rect2(tile.position + tile.size * 0.5 - tile.size * tile.scale * 0.5, tile.size * tile.scale)
		if r.grow(8.0).has_point(local):
			return i
	return -1

func go_to(i: int, secs: float = 0.22) -> void:
	i = clampi(i, 0, maxi(nodes.size() - 1, 0))
	if _scroll_tween:
		_scroll_tween.kill()
	if secs <= 0.0:
		scroll = float(i)
	else:
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(self, "scroll", float(i), secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if i != index:
		index = i
		index_changed.emit(i)
	Perf.kick(secs + 0.2)

func step(d: int) -> bool:
	var target := index + d
	if target < 0 or target >= nodes.size():
		nudge(d)
		return false
	go_to(target)
	return true

## Tiny rubber-band when a move is blocked.
func nudge(dir: int) -> void:
	if _nudge_tween:
		_nudge_tween.kill()
	over = 0.0
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(self, "over", -dir * 16.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(self, "over", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Perf.kick(0.5)

func stop_tweens() -> void:
	if _scroll_tween:
		_scroll_tween.kill()
