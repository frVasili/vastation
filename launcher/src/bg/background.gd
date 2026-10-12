class_name Background
extends Control
## Always-visible scene at half resolution: gradient + accent glow + orbs (2D) and ~40 drifting glass prisms (3D).

const CUBES := 18
var accent_a := Color("16345c"):
	set(v):
		accent_a = v
		_apply()
var accent_b := Color("2f7fd6"):
	set(v):
		accent_b = v
		_apply()
var _bg_mat := ShaderMaterial.new()
var _glass_mat := ShaderMaterial.new()
var _vp2d: SubViewport
var _vp3d: SubViewport
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp2d = _make_layer()
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_mat.shader = Fx.shader("bg")
	rect.material = _bg_mat
	_vp2d.add_child(rect)
	# ColorRect inside a SubViewport needs an explicit size: follow the viewport
	_vp2d.size_changed.connect(func() -> void: rect.size = Vector2(_vp2d.size))
	_vp3d = _make_layer(true)
	_vp3d.transparent_bg = true
	_vp3d.own_world_3d = true
	_build_cubes(_vp3d)
	_apply()

func _make_layer(additive: bool = false) -> SubViewport:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.stretch_shrink = 2
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if additive:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nrender_mode blend_add;\nvoid fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }"
		var m := ShaderMaterial.new()
		m.shader = sh
		cont.material = m
	add_child(cont)
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	vp.gui_disable_input = true
	cont.add_child(vp)
	return vp

func _build_cubes(vp: SubViewport) -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.position = Vector3(0, 0, 11)
	vp.add_child(cam)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = GlassBox.get_mesh(false)
	mm.instance_count = CUBES
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	for i in CUBES:
		var depth := rng.randf_range(-26.0, -4.0)
		var pos := Vector3(rng.randf_range(-13.0, 13.0), rng.randf_range(-6.0, 6.0), depth)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		var size := rng.randf_range(1.0, 4.0)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.015, 0.06) * (1.0 if rng.randf() > 0.5 else -1.0), size, rng.randf_range(0.04, 0.10)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	_glass_mat.shader = Fx.shader("glass")
	mi.material_override = _glass_mat
	vp.add_child(mi)

func refresh_theme() -> void:
	_apply()

func _apply() -> void:
	# the tile accent tints the glow; the theme accent pulls it towards the theme's colour
	_bg_mat.set_shader_parameter("accent_a", accent_a.lerp(Pal.blue, 0.25))
	_bg_mat.set_shader_parameter("accent_b", accent_b.lerp(Pal.blue, 0.3))
	_bg_mat.set_shader_parameter("void_c", Pal.void_c)
	_bg_mat.set_shader_parameter("indigo_c", Pal.indigo)
	_bg_mat.set_shader_parameter("cyan_c", Pal.cyan)
	_glass_mat.set_shader_parameter("tint_a", accent_b.lerp(Pal.blue, 0.5))
	_glass_mat.set_shader_parameter("tint_b", accent_b.lerp(Pal.cyan, 0.6))

## Tint the whole scene towards a tile's accent (lerp over 0.6 s).
func tint_to(a: Color, b: Color, secs: float = 0.6) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "accent_a", a, secs)
	_tween.tween_property(self, "accent_b", b, secs)

## Stop/start rendering (dormant: the stream shows an app, nothing here is visible).
func set_rendering(on: bool) -> void:
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_vp2d.render_target_update_mode = mode
	_vp3d.render_target_update_mode = mode
