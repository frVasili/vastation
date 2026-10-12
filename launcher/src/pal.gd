class_name Pal
extends RefCounted
## Palette. A theme may override any of these in theme.json ("palette": {"accent": "#..."}).
## Keys: void (darkest background), deep (background gradient end), accent, highlight (glow / frame / lit edges), text.

static var void_c := Color("03040c")
static var indigo := Color("0a1038")  # "deep"
static var blue := Color("2b5cff")  # "accent"
static var cyan := Color("7fd8ff")  # "highlight"
static var text := Color("f2f6ff")

static func reset() -> void:
	void_c = Color("03040c")
	indigo = Color("0a1038")
	blue = Color("2b5cff")
	cyan = Color("7fd8ff")
	text = Color("f2f6ff")

static func apply(overrides: Dictionary) -> void:
	for key: String in overrides:
		var s := str(overrides[key])
		if not Color.html_is_valid(s):
			print("[theme] bad colour for palette.%s: %s" % [key, s])
			continue
		var c := Color(s)
		match key:
			"void": void_c = c
			"deep", "indigo": indigo = c
			"accent", "blue": blue = c
			"highlight", "cyan": cyan = c
			"text": text = c
