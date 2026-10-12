class_name TileArt
extends Control
## The face of a tile (glass slab + content), or its reflection when `mirror` is set.

var _body := ColorRect.new()
var _mat := ShaderMaterial.new()
var _content := TileContent.new()

func setup(t: Dictionary, mirror: bool) -> void:
	var w := float(t["w"])
	size = Vector2(w, Catalog.BASE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = size
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat.shader = Fx.shader("tile")
	_mat.set_shader_parameter("tile_size", size)
	_mat.set_shader_parameter("accent_a", t["color_a"])
	_mat.set_shader_parameter("accent_b", t["color_b"])
	_mat.set_shader_parameter("mirror_strength", 0.3 if mirror else 0.0)
	var art: Dictionary = t.get("art", {})
	var cover_name := str(art.get("cover", ""))
	if cover_name != "":
		var tex := ThemeStore.texture(cover_name, 640)
		if tex != null:
			_mat.set_shader_parameter("cover", tex)
			_mat.set_shader_parameter("has_cover", true)
			var ta := float(tex.get_width()) / float(tex.get_height())
			var ba := size.x / size.y
			_mat.set_shader_parameter("cover_crop", Vector2(ba / ta, 1.0) if ta > ba else Vector2(1.0, ta / ba))
	_body.material = _mat
	add_child(_body)
	_content.setup(t, mirror)
	add_child(_content)

func set_brightness(b: float) -> void:
	_mat.set_shader_parameter("brightness", b)
