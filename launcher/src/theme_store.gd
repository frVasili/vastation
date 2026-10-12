class_name ThemeStore
extends RefCounted
## Themes: plain folders (theme.json, sounds/, art/, wordmark.png), every part optional. Roots, first hit wins
## per file: <user dir>/themes, <binary dir>/themes, res://themes. Within a root the active theme is tried
## first, then "default". The user dir is $VASTATION_USER_DIR (tiles.json, art/, themes/).

const IMG_EXT: Array[String] = ["png", "jpg", "jpeg", "webp", "svg"]
static var active := "default"
static var meta := {}
static var _tex := {}

static func user_dir() -> String:
	return OS.get_environment("VASTATION_USER_DIR")

static func _roots() -> Array[String]:
	var out: Array[String] = []
	if user_dir() != "":
		out.append(user_dir().path_join("themes"))
	var beside := OS.get_executable_path().get_base_dir().path_join("themes")
	if DirAccess.dir_exists_absolute(beside):
		out.append(beside)
	out.append("res://themes")
	return out

static func available() -> Array[String]:
	var out: Array[String] = ["default"]
	for root in _roots():
		# res://themes only exists when running from the project; an empty user folder may lack themes/.
		if not DirAccess.dir_exists_absolute(root):
			continue
		for d in DirAccess.get_directories_at(root):
			if d not in out and FileAccess.file_exists(root.path_join(d).path_join("theme.json")):
				out.append(d)
	return out

static func initial() -> String:
	var wanted := OS.get_environment("VASTATION_THEME")
	if wanted == "":
		wanted = Prefs.text("theme")
	return wanted if wanted in available() else "default"

static func set_active(theme: String) -> void:
	active = theme
	_tex.clear()
	var base := _read_json(find("theme.json", "default"))
	var mine := _read_json(find("theme.json"))
	var palette: Dictionary = base.get("palette", {})
	palette.merge(mine.get("palette", {}) as Dictionary, true)
	meta = base
	meta.merge(mine, true)
	meta["palette"] = palette
	Pal.reset()
	Pal.apply(palette)

static func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

static func dirs(theme: String) -> Array[String]:
	var out: Array[String] = []
	for root in _roots():
		out.append(root.path_join(theme))
	if theme != "default":
		for root in _roots():
			out.append(root.path_join("default"))
	return out

static func find(rel: String, theme: String = "") -> String:
	for d in dirs(theme if theme != "" else active):
		var p := d.path_join(rel)
		if FileAccess.file_exists(p):
			return p
	return ""

static func system_name() -> String:
	return str(meta.get("system_name", "VAStation"))

static func tagline() -> String:
	return str(meta.get("tagline", "home entertainment system"))

static func theme_title() -> String:
	return str(meta.get("name", active))

static func use_logos() -> bool:
	return bool(meta.get("use_logos", true))

static func sound(sound_name: String) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var p := find("sounds/%s.%s" % [sound_name, ext])
		if p == "":
			continue
		if ext == "wav":
			return AudioStreamWAV.load_from_file(p)
		return AudioStreamOggVorbis.load_from_file(p)
	return null

## Where a logo/cover is: a bare name is searched in the theme's art, default's art, then <user dir>/art;
## a value with "/" or an extension is a path relative to the user dir.
static func art_path(art_name: String) -> String:
	if art_name == "":
		return ""
	var ud := user_dir()
	if art_name.contains("/") or art_name.get_extension() != "":
		if ud == "":
			return ""
		var rel := ud.path_join(art_name)
		return rel if FileAccess.file_exists(rel) else ""
	for d in dirs(active):
		for ext in IMG_EXT:
			var p := d.path_join("art").path_join("%s.%s" % [art_name, ext])
			if FileAccess.file_exists(p):
				return p
	if ud != "":
		for ext in IMG_EXT:
			var p := ud.path_join("art").path_join("%s.%s" % [art_name, ext])
			if FileAccess.file_exists(p):
				return p
	return ""

static func load_image(path: String, px: int) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"svg":
			if img.load_svg_from_buffer(bytes, 1.0) == OK:
				var longest := float(maxi(img.get_width(), img.get_height()))
				err = img.load_svg_from_buffer(bytes, float(px) / maxf(longest, 1.0))
		"png": err = img.load_png_from_buffer(bytes)
		"webp": err = img.load_webp_from_buffer(bytes)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(bytes)
	return img if err == OK else null

## Logo/cover texture by name or user-relative path. SVGs are rasterised to `px` on the long side.
static func texture(art_name: String, px: int) -> Texture2D:
	var key := "%s@%d" % [art_name, px]
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	var p := art_path(art_name)
	if p != "":
		var img := load_image(p, px)
		if img != null:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

## Wordmark image for the boot sequence, or null.
static func wordmark() -> Texture2D:
	var p := find("wordmark.png")
	if p == "":
		return null
	var img := load_image(p, 0)
	return null if img == null else ImageTexture.create_from_image(img)
