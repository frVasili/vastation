class_name Sfx
extends Node
## Sound cues + ambient loop. Static play() so UI code does not need a reference.

static var inst: Sfx
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _ambient := AudioStreamPlayer.new()
var _ambient_tween: Tween
const AMBIENT_DB := -17.0

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	add_child(_ambient)
	_ambient.volume_db = -60.0
	reload()
	apply_volume()

func reload() -> void:
	_streams.clear()
	for n in ["nav", "tab", "select", "back", "error", "launch", "boot"]:
		_streams[n] = ThemeStore.sound(n)
	var amb := ThemeStore.sound("ambient")
	if amb is AudioStreamWAV:
		var w := amb as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / (4 if w.stereo else 2)
	_ambient.stream = amb

func apply_volume() -> void:
	var v := Prefs.volume() / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))

static func play(cue: String) -> void:
	if inst == null:
		return
	var s: AudioStream = inst._streams.get(cue)
	if s == null:
		return
	for p in inst._pool:
		if not p.playing:
			p.stream = s
			p.play()
			return
	inst._pool[0].stream = s
	inst._pool[0].play()

## Ambient loop on/off with a fade.
static func ambient(on: bool, secs: float = 2.0) -> void:
	if inst == null or inst._ambient.stream == null:
		return
	var a := inst._ambient
	if inst._ambient_tween:
		inst._ambient_tween.kill()
	if on and Prefs.flag("ambient"):
		if not a.playing:
			a.play()
		a.stream_paused = false
		inst._ambient_tween = inst.create_tween()
		inst._ambient_tween.tween_property(a, "volume_db", AMBIENT_DB, secs)
	else:
		inst._ambient_tween = inst.create_tween()
		inst._ambient_tween.tween_property(a, "volume_db", -60.0, secs)
		inst._ambient_tween.tween_callback(func() -> void: a.stream_paused = true)

static func pause_all(paused: bool) -> void:
	if inst != null:
		inst._ambient.stream_paused = paused or inst._ambient.volume_db < -50.0

static func stop_cue(cue: String) -> void:
	if inst == null:
		return
	for p in inst._pool:
		if p.playing and p.stream == inst._streams.get(cue):
			p.stop()
