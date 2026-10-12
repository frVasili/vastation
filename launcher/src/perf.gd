class_name Perf
extends RefCounted
## Frame-rate governor: 60 fps after input / during animation, 30 idle, 2 dormant.

static var enabled := true
static var dormant := false
static var _until_ms := 0

static func kick(secs: float = 0.5) -> void:
	_until_ms = maxi(_until_ms, Time.get_ticks_msec() + int(secs * 1000.0))

static func input() -> void:
	kick(4.0)

static func tick() -> void:
	if not enabled or dormant:
		return
	var want := 60 if Time.get_ticks_msec() < _until_ms else 30
	if Engine.max_fps != want:
		Engine.max_fps = want

static func set_dormant(on: bool) -> void:
	dormant = on
	if enabled:
		Engine.max_fps = 2 if on else 60
	if not on:
		kick(2.0)
