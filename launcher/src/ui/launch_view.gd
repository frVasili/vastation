class_name LaunchView
extends Control
## Launch screen: home fades out, the tile glides to the centre, the screen floods with its accent,
## "Starting X" + progress + spinner. Also the way back (wake) is handled by main fading this out.

var _flood: ColorRect
var _tile_node: Tile
var _title: LabelLine
var _status: LabelLine
var _hint: LabelLine
var _spinner := Spinner.new()
var _flood_mat := ShaderMaterial.new()
var _tile: Dictionary = {}
var _tween: Tween
var _dismiss_tween: Tween
var _gen := 0
var _arrived := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_layout_texts)

func begin(tile: Dictionary, from_center: Vector2, from_scale: float) -> void:
	_gen += 1
	if _tween:
		_tween.kill()
	if _dismiss_tween:
		_dismiss_tween.kill()
	_clear()
	_arrived = false
	_tile = tile
	visible = true
	modulate.a = 1.0
	_flood = ColorRect.new()
	_flood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 a : source_color; uniform vec4 b : source_color; uniform float amt = 0.0;
void fragment(){ vec2 d=(UV-vec2(0.5,0.38))*vec2(1.6,1.0); float g=exp(-dot(d,d)*2.2);
vec3 c=mix(a.rgb*0.55, b.rgb, g*0.85); c=mix(vec3(0.01,0.015,0.05), c, 0.9); COLOR=vec4(c, amt);}"""
	_flood_mat.shader = sh
	_flood_mat.set_shader_parameter("a", tile["color_a"])
	_flood_mat.set_shader_parameter("b", tile["color_b"])
	_flood_mat.set_shader_parameter("amt", 0.0)
	_flood.material = _flood_mat
	add_child(_flood)
	_tile_node = Tile.new()
	_tile_node.setup(tile)
	add_child(_tile_node)
	_tile_node.apply_focus(1.0, 1.0)
	_tile_node.position = from_center - _tile_node.size * 0.5
	_tile_node.scale = Vector2.ONE * from_scale
	var target := _target()
	var name_text := str(tile.get("title", ""))
	_title = LabelLine.make("Starting " + name_text, 48, 800, Pal.text, 1)
	_status = LabelLine.make("Starting...", 28, 500, Color(Pal.text, 0.85))
	_status.align = HORIZONTAL_ALIGNMENT_CENTER
	_title.align = HORIZONTAL_ALIGNMENT_CENTER
	_hint = LabelLine.make("Back to VAStation: tap HOME in the top bar, or START + D-PAD UP + RB", 24, 600, Color(Pal.text, 0.7))
	_hint.align = HORIZONTAL_ALIGNMENT_CENTER
	_layout_texts()
	for n: Control in [_title, _status, _hint, _spinner]:
		n.modulate.a = 0.0
		add_child(n)
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float) -> void: _flood_mat.set_shader_parameter("amt", v), 0.0, 0.94, 0.9)
	_tween.tween_property(_tile_node, "position", target - _tile_node.size * 0.5, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_tile_node, "scale", Vector2.ONE * 1.25, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for n: Control in [_title, _status, _hint, _spinner]:
		_tween.tween_property(n, "modulate:a", 1.0, 0.5).set_delay(0.5)
	_tween.chain().tween_callback(func() -> void: _arrived = true)
	Perf.kick(1.5)

func _target() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.31)

func _layout_texts() -> void:
	if _title == null or not is_instance_valid(_title) or _title.is_queued_for_deletion():
		return
	var w := size.x - 160.0
	for l: LabelLine in [_title, _status, _hint]:
		l.box_w = w
	_title.position = Vector2(80, size.y * 0.31 + Catalog.BASE_H * 0.5 * 1.25 + 30.0)
	_status.position = Vector2(80, _title.position.y + _title.size.y + 4.0)
	_hint.position = Vector2(80, size.y - 48.0 - _hint.size.y)
	_spinner.position = Vector2(size.x * 0.5, _status.position.y + _status.size.y + 52.0)
	if _arrived and is_instance_valid(_tile_node) and not _tile_node.is_queued_for_deletion():
		_tile_node.position = _target() - _tile_node.size * 0.5

func set_progress(stage: String, detail: String) -> void:
	if _status == null:
		return
	var name_text := str(_tile.get("title", ""))
	match stage:
		"pulling": _status.text = detail if detail != "" else "Downloading %s (first start can take a few minutes)" % name_text
		"starting": _status.text = "Starting..."
		"joined": _status.text = "Almost there..."
		_: _status.text = "Preparing..."

## Fade the whole view out (back to home) and hide it.
func dismiss(secs: float) -> void:
	_gen += 1
	var g := _gen
	if _tween:
		_tween.kill()
	if _dismiss_tween:
		_dismiss_tween.kill()
	var tw := create_tween()
	_dismiss_tween = tw
	tw.tween_property(self, "modulate:a", 0.0, secs)
	tw.tween_callback(func() -> void:
		if g == _gen:
			_clear())
	Perf.kick(secs + 0.2)

func _clear() -> void:
	visible = false
	for c in get_children():
		if c != _spinner:
			c.queue_free()
	if _spinner.get_parent() == self:
		remove_child(_spinner)

class Spinner extends Control:
	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 6.0, true)
		var a := t * 2.2
		draw_arc(Vector2.ZERO, 22.0, a, a + 1.7, 24, Color(1, 1, 1, 0.95), 6.0, true)
