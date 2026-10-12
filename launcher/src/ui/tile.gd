class_name Tile
extends Control
## A carousel tile: glow frame, face, floor reflection, RUNNING pill. Origin = top-left of the unscaled tile.

const GLOW_PAD := 70.0
var data: Dictionary
var w := 270.0
var art := TileArt.new()
var mirror := TileArt.new()
var _glow := ColorRect.new()
var _glow_mat := ShaderMaterial.new()
var _pill := RunningPill.new()
var focus := 0.0

func setup(t: Dictionary) -> void:
	data = t
	w = float(t["w"])
	size = Vector2(w, Catalog.BASE_H)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.position = Vector2(-GLOW_PAD, -GLOW_PAD)
	_glow.size = size + Vector2(GLOW_PAD, GLOW_PAD) * 2.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_mat.shader = Fx.shader("glow")
	_glow_mat.set_shader_parameter("tile_size", size)
	_glow_mat.set_shader_parameter("pad", GLOW_PAD)
	_glow_mat.set_shader_parameter("halo_col", (t["color_b"] as Color).lerp(Pal.blue, 0.35).lightened(0.15))
	_glow_mat.set_shader_parameter("frame_col", Pal.cyan.lerp(Color.WHITE, 0.35))
	_glow.material = _glow_mat
	_glow.visible = false
	add_child(_glow)
	# mirror: flipped about the bottom edge, so its local y = 300 sits on the tile's bottom
	mirror.setup(t, true)
	mirror.pivot_offset = Vector2.ZERO
	mirror.scale = Vector2(1, -1)
	mirror.position = Vector2(0, Catalog.BASE_H * 2.0)
	add_child(mirror)
	art.setup(t, false)
	add_child(art)
	_pill.position = Vector2(14, 14)
	_pill.visible = false
	add_child(_pill)

func set_running(on: bool) -> void:
	_pill.visible = on

## f = focus weight 0..1; pulse = breathing 0..1.
func apply_focus(f: float, pulse: float) -> void:
	focus = f
	var sc := lerpf(0.9, 1.15, f)
	scale = Vector2(sc, sc)
	var b := lerpf(0.7, 1.0, f)
	art.set_brightness(b)
	mirror.set_brightness(b)
	_glow.visible = f > 0.02
	if _glow.visible:
		_glow_mat.set_shader_parameter("amount", f)
		_glow_mat.set_shader_parameter("pulse", pulse)
