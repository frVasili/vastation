extends SceneTree
## Renders the Moonlight box-art icon for the VAStation entry (600x800 PNG, original artwork).
## xvfb-run -a godot --path launcher --rendering-driver opengl3 --audio-driver Dummy --resolution 600x800 -s ../tools/make_icon.gd -- <out.png>
var frames := 0

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var out := Control.new()
	out.name = "Icon"
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(out)
	out.draw.connect(func() -> void:
		var size := Vector2(600, 800)
		for i in 80:
			var t := i / 79.0
			out.draw_rect(Rect2(0, t * size.y, size.x, size.y / 79.0 + 1.0), Color("#03040c").lerp(Color("#12206e"), t))
		for r in range(48, 0, -1):
			out.draw_circle(Vector2(300, 330), r * 7.0, Color(0.17, 0.36, 1.0, 0.012))
		var cube := PackedVector2Array([Vector2(300, 190), Vector2(420, 255), Vector2(420, 395), Vector2(300, 460), Vector2(180, 395), Vector2(180, 255)])
		out.draw_colored_polygon(cube, Color(0.5, 0.85, 1.0, 0.16))
		out.draw_colored_polygon(PackedVector2Array([cube[0], cube[1], Vector2(300, 320), cube[5]]), Color(0.7, 0.92, 1.0, 0.30))
		out.draw_colored_polygon(PackedVector2Array([cube[1], cube[2], cube[3], Vector2(300, 320)]), Color(0.3, 0.55, 1.0, 0.22))
		out.draw_rect(Rect2(210, 618, 180, 6), Color("#7fd8ff")))
	_label(out, "VASTATION", 78, 800, 510, Color("#f2f6ff"))
	_label(out, "LAUNCHER", 30, 600, 640, Color(0.95, 0.96, 1.0, 0.7))

func _label(parent: Control, text: String, size: int, weight: int, y: float, color: Color) -> void:
	var font := FontVariation.new()
	font.base_font = load("res://fonts/Exo2.ttf")
	font.variation_opentype = {"wght": weight}
	font.spacing_glyph = 4
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(600, size * 1.4)
	parent.add_child(label)

func _process(_delta: float) -> bool:
	frames += 1
	root.get_node("Icon").queue_redraw()  # glyphs are rasterised lazily: redraw until they are there
	if frames == 30:
		var args := OS.get_cmdline_user_args()
		root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "icon.png")
		return true
	return false
