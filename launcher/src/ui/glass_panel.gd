class_name GlassPanel
extends ColorRect
## Rounded dark-glass panel (panel.gdshader).

func _init(panel_size: Vector2 = Vector2(400, 300), radius: float = 28.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var m := ShaderMaterial.new()
	m.shader = Fx.shader("panel")
	m.set_shader_parameter("radius", radius)
	material = m
	resize(panel_size)
	refresh_theme()

func resize(panel_size: Vector2) -> void:
	size = panel_size
	custom_minimum_size = panel_size
	(material as ShaderMaterial).set_shader_parameter("panel_size", panel_size)

func refresh_theme() -> void:
	var m := material as ShaderMaterial
	m.set_shader_parameter("top_col", Color(Pal.indigo.lerp(Pal.blue, 0.3), 0.98))
	m.set_shader_parameter("bottom_col", Color(Pal.void_c.lerp(Pal.indigo, 0.5), 0.99))
	m.set_shader_parameter("edge_col", Pal.cyan.lerp(Pal.blue, 0.2))
