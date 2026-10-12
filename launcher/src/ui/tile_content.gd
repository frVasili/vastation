class_name TileContent
extends Control
## Logo / monogram / vector glyph on top of the tile face. `fade` makes it a floor reflection.

var tile: Dictionary
var logo: Texture2D
var _px := 380

func setup(t: Dictionary, mirror: bool) -> void:
	tile = t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(float(t["w"]), Catalog.BASE_H)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var art: Dictionary = t.get("art", {})
	if str(art.get("cover", "")) == "" and ThemeStore.use_logos():
		logo = ThemeStore.texture(str(art.get("logo", "")), _px)
	if mirror:
		var m := ShaderMaterial.new()
		m.shader = Fx.shader("fade")
		m.set_shader_parameter("tile_h", Catalog.BASE_H)
		material = m
	queue_redraw()

func _draw() -> void:
	if tile.is_empty():
		return
	var art: Dictionary = tile.get("art", {})
	if str(art.get("cover", "")) != "":
		return
	var c := size * 0.5
	if logo != null:
		var longest := maxf(logo.get_width(), logo.get_height())
		var target := Catalog.BASE_H * 0.55
		var s := Vector2(logo.get_width(), logo.get_height()) * (target / longest)
		draw_texture_rect(logo, Rect2(c - s * 0.5 + Vector2(0, 7), s), false, Color(0, 0, 0.1, 0.28))
		draw_texture_rect(logo, Rect2(c - s * 0.5, s), false)
		return
	match str(art.get("glyph", "")):
		"settings": _gear(c)
		"power": _power(c)
		_: _monogram(c)

func _monogram(c: Vector2) -> void:
	var t := str(tile.get("title", "?")).substr(0, 1).to_upper()
	var f := Fx.font(800, 0)
	var px := 170
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := c + Vector2(-w * 0.5, f.get_ascent(px) * 0.5 - f.get_descent(px) * 0.3 - 8)
	draw_string(f, base + Vector2(0, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0.1, 0.28))
	draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, 0.95))

func _hole_color() -> Color:
	return (tile["color_a"] as Color).lerp(tile["color_b"] as Color, 0.55)

func _gear(c: Vector2) -> void:
	var white := Color(1, 1, 1, 0.95)
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var p0 := c + d * 52.0
		var p1 := c + d * 78.0
		draw_colored_polygon(PackedVector2Array([p0 - n * 18.0, p1 - n * 14.0, p1 + n * 14.0, p0 + n * 18.0]), white)
	draw_circle(c, 64.0, white, true, -1.0, true)
	draw_circle(c, 28.0, _hole_color(), true, -1.0, true)

func _power(c: Vector2) -> void:
	var white := Color(1, 1, 1, 0.95)
	draw_arc(c + Vector2(0, 6), 56.0, deg_to_rad(-60.0), deg_to_rad(240.0), 48, white, 16.0, true)
	for e in [deg_to_rad(-60.0), deg_to_rad(240.0)]:
		draw_circle(c + Vector2(0, 6) + Vector2.from_angle(e as float) * 56.0, 8.0, white, true, -1.0, true)
	draw_line(c + Vector2(0, -64), c + Vector2(0, -10), white, 16.0, true)
	draw_circle(c + Vector2(0, -64), 8.0, white, true, -1.0, true)
	draw_circle(c + Vector2(0, -10), 8.0, white, true, -1.0, true)
