class_name Fx
extends RefCounted
## Fonts (one variable typeface, weights via FontVariation) and small drawing helpers.

static var _base: Font
static var _cache := {}

static func font(weight: int = 500, spacing: int = 0) -> FontVariation:
	var key := weight * 1000 + spacing + 100
	if _cache.has(key):
		return _cache[key]
	if _base == null:
		_base = load("res://fonts/Exo2.ttf")
	var fv := FontVariation.new()
	fv.base_font = _base
	var tag := TextServerManager.get_primary_interface().name_to_tag("weight")
	fv.variation_opentype = {tag: weight}
	fv.spacing_glyph = spacing
	_cache[key] = fv
	return fv

static func text_width(text: String, weight: int, spacing: int, px: int) -> float:
	return font(weight, spacing).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

## Largest size <= px so that the text fits max_w.
static func fit_size(text: String, weight: int, spacing: int, px: int, max_w: float) -> int:
	var w := text_width(text, weight, spacing, px)
	if w <= max_w or max_w <= 0.0:
		return px
	return maxi(24, int(px * max_w / w))

static func now_ms() -> int:
	return Time.get_ticks_msec()

static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

static func shader(name: String) -> Shader:
	return load("res://src/shaders/%s.gdshader" % name)
