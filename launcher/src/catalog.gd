class_name Catalog
extends RefCounted
## Categories + tiles from catalog/default.json, then the user's tiles.json merged on top.
## Bad entries are skipped with a "[catalog]" line each; the first problem is kept in `notice`.

const BASE_H := 270.0
const WIDTHS := {"square": 270.0, "cover": 180.0, "banner": 480.0}
const LAUNCH_TYPES: Array[String] = ["wolf_app", "wolf_runner", "internal"]

var categories: Array[Dictionary] = []
var tiles: Array[Dictionary] = []
var order: Dictionary = {}
## "tiles.json: <first problem>" or "".
var notice := ""

func load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("catalog: cannot parse " + path)
		return
	var root := parsed as Dictionary
	for c: Dictionary in root.get("categories", []):
		categories.append(c)
	for t: Dictionary in root.get("tiles", []):
		tiles.append(_normalise(t))

func _warn(msg: String) -> void:
	print("[catalog] tiles.json: " + msg)
	if notice == "":
		notice = "tiles.json: " + msg

func _normalise(t: Dictionary) -> Dictionary:
	var art: Dictionary = t.get("art", {})
	var shape := str(art.get("shape", "square"))
	if not WIDTHS.has(shape):
		shape = "square"
	var acc: Array = art.get("accent", ["#16345c", "#2f7fd6"])
	var ca := Color("#16345c")
	var cb := Color("#2f7fd6")
	if acc.size() >= 2 and Color.html_is_valid(str(acc[0])) and Color.html_is_valid(str(acc[1])):
		ca = Color(str(acc[0]))
		cb = Color(str(acc[1]))
	t["art"] = art
	t["shape"] = shape
	t["w"] = float(WIDTHS[shape])
	t["color_a"] = ca
	t["color_b"] = cb
	if not t.has("subtitle"):
		t["subtitle"] = ""
	return t

## Merge <user dir>/tiles.json. Never throws: problems become warnings.
func apply_user(user_dir: String) -> void:
	if user_dir == "":
		return
	var path := user_dir.path_join("tiles.json")
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_warn("not valid JSON (check commas and quotes)")
		return
	var root := parsed as Dictionary
	_user_categories(root.get("categories", []))
	_user_tiles(root.get("tiles", []))
	var hide: Variant = root.get("hide", [])
	if hide is Array:
		var keep: Array[Dictionary] = []
		for t in tiles:
			if str(t.get("id", "")) not in (hide as Array).map(func(h: Variant) -> String: return str(h)):
				keep.append(t)
		tiles = keep
	var ord: Variant = root.get("order", {})
	if ord is Dictionary:
		order = ord as Dictionary

func _user_categories(list: Variant) -> void:
	if not list is Array:
		_warn("'categories' must be a list")
		return
	for c: Variant in list as Array:
		if not c is Dictionary or not _valid_id((c as Dictionary).get("id", null)) or str((c as Dictionary).get("title", "")) == "":
			_warn("category needs an id (a-z 0-9 _ -) and a title")
			continue
		var d := c as Dictionary
		var found := false
		for ex in categories:
			if str(ex["id"]) == str(d["id"]):
				ex["title"] = str(d["title"])
				found = true
		if not found:
			categories.append({"id": str(d["id"]), "title": str(d["title"])})

func _valid_id(v: Variant) -> bool:
	if not v is String:
		return false
	var rx := RegEx.new()
	rx.compile("^[a-z0-9_-]+$")
	return rx.search(v as String) != null

func _cat_exists(id: String) -> bool:
	for c in categories:
		if str(c["id"]) == id:
			return true
	return false

func _user_tiles(list: Variant) -> void:
	if not list is Array:
		_warn("'tiles' must be a list")
		return
	var n := 0
	for item: Variant in list as Array:
		n += 1
		var problem := _tile_problem(item)
		if problem != "":
			var label := str((item as Dictionary).get("id", "#%d" % n)) if item is Dictionary else "#%d" % n
			_warn("tile %s: %s" % [label, problem])
			continue
		var t := _normalise((item as Dictionary).duplicate(true))
		var replaced := false
		for i in tiles.size():
			if str(tiles[i]["id"]) == str(t["id"]):
				tiles[i] = t
				replaced = true
		if not replaced:
			tiles.append(t)

func _tile_problem(item: Variant) -> String:
	if not item is Dictionary:
		return "is not an object"
	var t := item as Dictionary
	if not _valid_id(t.get("id", null)):
		return "id must be lowercase letters, digits, - or _"
	if str(t.get("title", "")) == "":
		return "title is missing"
	if not _cat_exists(str(t.get("category", ""))):
		return "category '%s' does not exist" % str(t.get("category", ""))
	var l: Variant = t.get("launch", null)
	if not l is Dictionary:
		return "launch is missing"
	var lt := str((l as Dictionary).get("type", ""))
	if lt not in LAUNCH_TYPES:
		return "launch.type must be wolf_app, wolf_runner or internal"
	if lt == "wolf_app" and str((l as Dictionary).get("app", "")) == "":
		return "launch.app is missing"
	if lt == "wolf_runner" and not (l as Dictionary).get("runner", null) is Dictionary:
		return "launch.runner is missing"
	return ""

func tiles_in(category_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in tiles:
		if t.get("category", "") == category_id:
			out.append(t)
	var listed: Variant = order.get(category_id, [])
	if listed is Array:
		var first: Array[Dictionary] = []
		for id: Variant in listed as Array:
			for t in out:
				if str(t["id"]) == str(id) and t not in first:
					first.append(t)
		for t in out:
			if t not in first:
				first.append(t)
		return first
	return out
