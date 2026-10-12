class_name Clock
extends RefCounted
## Launcher clock = UTC + offset of the chosen time zone. glibc does not re-read TZ at runtime, so the offset is
## asked from `date +%z` (a child process inherits the new TZ) on zone change and every 10 minutes (DST).

const ZONES: Array[Array] = [
	["America/New_York", "Eastern"], ["America/Chicago", "Central"], ["America/Denver", "Mountain"],
	["America/Phoenix", "Arizona"], ["America/Los_Angeles", "Pacific"], ["America/Anchorage", "Alaska"],
	["Pacific/Honolulu", "Hawaii"], ["Europe/London", "London"], ["Europe/Paris", "Central Europe"],
	["Europe/Athens", "Eastern Europe"], ["Asia/Dubai", "Dubai"], ["Asia/Kolkata", "India"],
	["Asia/Tokyo", "Japan"], ["Australia/Sydney", "Sydney"], ["UTC", "UTC"],
]
const REFRESH_MS := 600000
## Bumped on every zone change so the UI can redraw.
static var version := 0
static var _offset := 0
static var _valid := false
static var _next_ms := 0

static func zone() -> String:
	var z := Prefs.text("timezone")
	if z == "":
		z = OS.get_environment("TZ")
	return z if z != "" else "America/New_York"

static func index_of(z: String) -> int:
	for i in ZONES.size():
		if ZONES[i][0] == z:
			return i
	return -1

static func label(z: String) -> String:
	var i := index_of(z)
	return z if i < 0 else str(ZONES[i][1])

## Next zone in the list; an unknown current zone starts from the top.
static func cycled(z: String, d: int) -> String:
	var i := index_of(z)
	if i < 0:
		return str(ZONES[0][0])
	return str(ZONES[posmod(i + d, ZONES.size())][0])

static func apply(z: String) -> void:
	OS.set_environment("TZ", z)
	refresh()
	version += 1

static func refresh() -> void:
	_next_ms = Time.get_ticks_msec() + REFRESH_MS
	var out: Array = []
	_valid = false
	if OS.execute("date", ["+%z"], out) == 0 and out.size() > 0:
		var s := str(out[0]).strip_edges()
		if s.length() == 5 and (s[0] == "+" or s[0] == "-") and s.substr(1).is_valid_int():
			var secs := int(s.substr(1, 2)) * 3600 + int(s.substr(3, 2)) * 60
			_offset = -secs if s[0] == "-" else secs
			_valid = true

static func tick() -> void:
	if Time.get_ticks_msec() >= _next_ms:
		refresh()

static func now() -> Dictionary:
	if not _valid:
		return Time.get_datetime_dict_from_system()
	return Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + _offset)
