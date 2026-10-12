class_name Prefs
extends RefCounted
## Settings persisted to user://settings.json.

const PATH := "user://settings.json"
static var persist := true
static var data := {"volume": 80, "ambient": true, "boot_animation": true, "clock_24h": true, "theme": ""}

static func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		var d := parsed as Dictionary
		for k: String in d:
			data[k] = d[k]
		if str(data.get("theme", "")) == "" and d.has("pack"):
			data["theme"] = str(d["pack"])  # old key, read once
		data.erase("pack")

static func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

static func volume() -> int:
	return clampi(int(data.get("volume", 80)), 0, 100)

static func flag(key: String) -> bool:
	return bool(data.get(key, true))

static func text(key: String) -> String:
	return str(data.get(key, ""))

static func put(key: String, value: Variant) -> void:
	data[key] = value
	save()
