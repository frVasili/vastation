class_name Boot
extends Control
## Boot sequence (~6.5 s): glide over glass towers in blue fog, bloom at 4.2 s, wordmark, crossfade out.

signal finished
## The crossfade to the home screen begins (main fades the home in).
signal fading

const T_BLOOM := 4.2
const T_FADE := 6.0
const T_END := 6.5
var t := 0.0
var _vp: SubViewport
var _cam: Camera3D
var _tower_mat := ShaderMaterial.new()
var _mote_mat := ShaderMaterial.new()
var _bloom := ColorRect.new()
var _bloom_mat := ShaderMaterial.new()
var _black := ColorRect.new()
var _word: Control
var _rule: Control
var _sub: LabelLine
var _skipping := false
var _done := false
var _fade_sent := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.stretch_shrink = 1
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.gui_disable_input = true
	cont.add_child(_vp)
	_build_scene()
	_bloom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom_mat.shader = Fx.shader("bloom")
	_bloom.material = _bloom_mat
	_bloom_mat.set_shader_parameter("col", Pal.cyan.lerp(Color.WHITE, 0.3))
	add_child(_bloom)
	_build_wordmark()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	Sfx.play("boot")
	_update(0.0)

func _fog() -> Color:
	return Pal.indigo.lerp(Pal.blue, 0.12)

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _fog()
	_cam = Camera3D.new()
	_cam.environment = env
	_cam.fov = 62.0
	_cam.far = 130.0
	_vp.add_child(_cam)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_2026
	var spots: Array[Transform3D] = []
	var z := 8.0
	while z > -110.0:
		var x := -42.0
		while x < 42.0:
			if absf(x) > 3.4 or z > 4.0:
				var w := rng.randf_range(1.5, 2.6)
				var h := 1.5 + pow(rng.randf(), 2.4) * 17.0
				var pos := Vector3(x + rng.randf_range(-0.5, 0.5), 0.0, z + rng.randf_range(-0.5, 0.5))
				if absf(pos.x) > 3.0:
					spots.append(Transform3D(Basis.from_scale(Vector3(w, h, w)), pos))
			x += 3.3
		z -= 3.3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = GlassBox.get_mesh(true)
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-60, -5, -130), Vector3(120, 40, 150))
	_tower_mat.shader = Fx.shader("towers")
	_tower_mat.set_shader_parameter("fog_col", _fog())
	_tower_mat.set_shader_parameter("body_col", Pal.indigo.lerp(Pal.void_c, 0.5))
	_tower_mat.set_shader_parameter("edge_col", Pal.cyan)
	_tower_mat.set_shader_parameter("glow_col", Pal.blue)
	mi.material_override = _tower_mat
	_vp.add_child(mi)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(260, 260)
	var fm := MeshInstance3D.new()
	fm.mesh = floor_mesh
	fm.position = Vector3(0, 0, -60)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = Fx.shader("floor")
	floor_mat.set_shader_parameter("fog_col", _fog())
	floor_mat.set_shader_parameter("glow_col", Pal.blue)
	fm.material_override = floor_mat
	_vp.add_child(fm)
	# light motes
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mmm := MultiMesh.new()
	mmm.transform_format = MultiMesh.TRANSFORM_3D
	mmm.use_custom_data = true
	mmm.mesh = quad
	mmm.instance_count = 140
	for i in 140:
		var p := Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(0.6, 9.0), rng.randf_range(-50.0, 0.0))
		mmm.set_instance_transform(i, Transform3D(Basis(), p))
		mmm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.12, 0.4), 0, 0))
	var mo := MultiMeshInstance3D.new()
	mo.multimesh = mmm
	mo.custom_aabb = AABB(Vector3(-20, -5, -60), Vector3(40, 30, 70))
	_mote_mat.shader = Fx.shader("mote")
	_mote_mat.set_shader_parameter("col", Pal.cyan)
	mo.material_override = _mote_mat
	_vp.add_child(mo)

func _build_wordmark() -> void:
	var W := 1280.0
	_word = Control.new()
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word)
	var vs := size if size.x > 0.0 else Vector2(W, 720.0)
	var title: Control
	var wm := ThemeStore.wordmark()
	if wm != null:
		var k := minf(vs.x * 0.7 / wm.get_width(), vs.y * 0.22 / wm.get_height())
		var tr := TextureRect.new()
		tr.texture = wm
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(wm.get_width(), wm.get_height()) * k
		title = tr
	else:
		var name_text := ThemeStore.system_name().to_upper()
		var px := Fx.fit_size(name_text, 700, 20, 132, vs.x * 0.78)
		title = LabelLine.make(name_text, px, 700, Color.WHITE, 20)
	_word.add_child(title)
	_sub = LabelLine.make(ThemeStore.tagline().to_upper(), 28, 500, Color(0.93, 0.98, 1.0, 1.0), 8)
	_word.add_child(_sub)
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	_word.add_child(_rule)
	title.position = Vector2(0, 0)
	_sub.position = Vector2(0, title.size.y + 40.0)
	_sub.box_w = title.size.x
	_sub.align = HORIZONTAL_ALIGNMENT_CENTER
	_rule.position = Vector2(0, title.size.y + 14.0)
	_rule.size = Vector2(title.size.x, 12)
	_word.size = Vector2(maxf(title.size.x, _sub.size.x), _sub.position.y + _sub.size.y)
	_word.pivot_offset = _word.size * 0.5
	_word.visible = false
	# centre on screen
	_word.set_meta("w", _word.size)

func _draw_rule() -> void:
	var k := clampf((t - 4.6) / 0.8, 0.0, 1.0)
	k = Fx.ease_out(k)
	var w := 340.0 * k
	var cx := _rule.size.x * 0.5
	for i in 3:
		var g := float(3 - i) * 8.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Pal.cyan, 0.10 + 0.05 * i)
		sb.set_corner_radius_all(int(3 + g))
		sb.anti_aliasing = true
		_rule.draw_style_box(sb, Rect2(cx - w * 0.5 - g, 3 - g, w + g * 2.0, 6 + g * 2.0))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0.9, 0.97, 1.0)
	bar.set_corner_radius_all(3)
	bar.anti_aliasing = true
	_rule.draw_style_box(bar, Rect2(cx - w * 0.5, 3, w, 6))

func _process(delta: float) -> void:
	t += delta
	_update(t)
	if t >= T_END and not _done:
		_finish()

func skip() -> void:
	if _skipping or _done:
		return
	_skipping = true
	_send_fade()
	Sfx.stop_cue("boot")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_finish)

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.is_pressed()) or (event is InputEventJoypadButton and event.is_pressed()):
		skip()

func _update(time_s: float) -> void:
	var k := clampf(time_s / T_BLOOM, 0.0, 1.0)
	var drive := time_s + 0.0
	_cam.position = Vector3(sin(drive * 0.35) * 0.6, 2.2 + 1.1 * k, -4.2 * drive - 0.4 * drive * drive * 0.08)
	_cam.rotation = Vector3(deg_to_rad(5.0 + 4.0 * k), sin(drive * 0.22) * 0.04, sin(drive * 0.3) * 0.02)
	_tower_mat.set_shader_parameter("sink", Fx.ease_out(clampf((time_s - T_BLOOM) / 1.6, 0.0, 1.0)))
	_mote_mat.set_shader_parameter("fade", clampf((time_s - 0.6) / 1.2, 0.0, 1.0) * (1.0 - clampf((time_s - T_BLOOM) / 1.4, 0.0, 0.7)))
	_black.color.a = 1.0 - clampf(time_s / 1.4, 0.0, 1.0)
	# bloom: quick swell at 4.2 s, then settles behind the wordmark
	var s := 0.0
	if time_s > T_BLOOM - 0.5:
		var up := clampf((time_s - (T_BLOOM - 0.5)) / 0.7, 0.0, 1.0)
		var down := clampf((time_s - (T_BLOOM + 0.2)) / 1.4, 0.0, 1.0)
		s = up * lerpf(2.4, 0.5, Fx.ease_out(down))
	_bloom_mat.set_shader_parameter("strength", s)
	# wordmark
	var a := clampf((time_s - 4.3) / 0.8, 0.0, 1.0)
	_word.visible = a > 0.0
	_word.modulate.a = Fx.ease_out(a)
	var sc := lerpf(1.08, 1.0, Fx.ease_out(clampf((time_s - 4.3) / 1.4, 0.0, 1.0)))
	var vs := size if size.x > 0.0 else Vector2(1280, 720)
	sc = minf(sc, vs.x * 0.8 / maxf(_word.size.x, 1.0))
	_word.scale = Vector2(sc, sc)
	_word.position = Vector2(vs.x * 0.5, vs.y * 0.44) - _word.size * 0.5
	_sub.modulate.a = clampf((time_s - 4.5) / 0.6, 0.0, 1.0)
	_rule.queue_redraw()
	if time_s > T_FADE:
		_send_fade()
		modulate.a = 1.0 - clampf((time_s - T_FADE) / (T_END - T_FADE), 0.0, 1.0)

func _send_fade() -> void:
	if not _fade_sent:
		_fade_sent = true
		fading.emit()
