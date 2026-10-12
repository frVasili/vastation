extends Control
## VAStation launcher root: wires backend, background, home, launch flow, dialogs, settings, dormant mode.

enum Mode { BOOT, HOME, SETTINGS, DIALOG, LAUNCHING, DORMANT }

var mode := Mode.BOOT
var backend: LauncherBackend
var catalog: Catalog
var bg: Background
var home: Home
var settings: SettingsPanel
var launch_view: LaunchView
var boot: Boot
var shots_mode := false
var _held := {}
var _launch_tile: Dictionary = {}
var _errors: Array = []
var _flushing := false
var _wake_until_ms := 0
var _debug_dir := ""
var _debug_n := 0
var _autolaunch := ""
var _last_motion_ms := 0
var _cursor_hidden := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots_mode = "--shots" in args
	Prefs.load_file()
	Prefs.persist = not shots_mode
	Clock.apply(Clock.zone())
	Perf.enabled = not shots_mode
	InputSetup.setup()
	ThemeStore.set_active(ThemeStore.initial())
	add_child(Sfx.new())
	_load_catalog()
	backend = _make_backend()
	add_child(backend)
	backend.launch_progress.connect(_on_progress)
	backend.launch_failed.connect(_on_failed)
	backend.foreground_changed.connect(_on_foreground)
	bg = Background.new()
	add_child(bg)
	_build_home()
	settings = SettingsPanel.new()
	add_child(settings)
	settings.setup(backend)
	settings.closed.connect(func() -> void: mode = Mode.HOME)
	settings.theme_chosen.connect(apply_theme)
	launch_view = LaunchView.new()
	add_child(launch_view)
	var skip := OS.get_environment("VASTATION_SKIP_BOOT") == "1" or not Prefs.flag("boot_animation")
	if skip:
		mode = Mode.HOME
		Sfx.ambient(true, 3.0)
	else:
		boot = Boot.new()
		add_child(boot)
		boot.fading.connect(_on_boot_fading)
		boot.finished.connect(_on_boot_finished)
		home.modulate.a = 0.0
	_setup_debug()
	_setup_cursor()
	if mode == Mode.HOME:
		_arm_autolaunch()
	if shots_mode:
		var shots := Shots.new()
		shots.m = self
		shots.out_dir = args[args.find("--shots") + 1]
		add_child(shots)

func _make_backend() -> LauncherBackend:
	var forced_mock := OS.get_environment("VASTATION_BACKEND") == "mock"
	var wolf_path := "res://src/backend/wolf_backend.gd"
	if not forced_mock and OS.get_environment("WOLF_SOCKET_PATH") != "" and ResourceLoader.exists(wolf_path):
		var script: GDScript = load(wolf_path)
		var node: Variant = script.new()
		if node is LauncherBackend:
			return node as LauncherBackend
	return MockBackend.new()

func _build_home() -> void:
	if home != null:
		home.queue_free()
	home = Home.new()
	home.setup(catalog, backend)
	home.activated.connect(_on_activated)
	home.stop_requested.connect(func(t: Dictionary) -> void: backend.stop(str(t.get("id", ""))))
	home.focus_changed.connect(_on_focus_changed)
	add_child(home)
	move_child(home, bg.get_index() + 1)
	if shots_mode:
		home.top.frozen = true
		home.top.clock_text = "21:07"
		home.top.date_text = "Mon 12 Oct"
	home.refresh_state()

func _load_catalog() -> void:
	catalog = Catalog.new()
	catalog.load_file("res://catalog/default.json")
	catalog.apply_user(ThemeStore.user_dir())

## Switch theme at once: palette, sounds, art, wordmark. Keeps the focused tile.
func apply_theme(theme: String) -> void:
	var keep := home.focused_tile() if home else {}
	ThemeStore.set_active(theme)
	Sfx.inst.reload()
	bg.refresh_theme()
	_build_home()
	if not keep.is_empty():
		home.focus_tile(keep)
	settings.refresh_theme()

## Re-read catalog + user tiles (screenshots).
func reload_catalog() -> void:
	_load_catalog()
	_build_home()

## Play the boot sequence again from t0 seconds (screenshots).
func play_boot(t0: float) -> Boot:
	boot = Boot.new()
	boot.t = t0
	add_child(boot)
	boot.fading.connect(_on_boot_fading)
	boot.finished.connect(_on_boot_finished)
	mode = Mode.BOOT
	return boot

func _on_focus_changed(tile: Dictionary) -> void:
	bg.tint_to(tile["color_a"] as Color, tile["color_b"] as Color)

# --- boot ----------------------------------------------------------------------------------
func _on_boot_fading() -> void:
	var tw := create_tween()
	tw.tween_property(home, "modulate:a", 1.0, 0.6)
	Perf.kick(1.0)

func _on_boot_finished() -> void:
	boot = null
	home.modulate.a = 1.0
	if mode == Mode.BOOT:
		mode = Mode.HOME
	Sfx.ambient(true, 4.0)
	_arm_autolaunch()

# --- input ---------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_motion_ms = Time.get_ticks_msec()
		if _cursor_hidden:
			_cursor_hidden = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouse or event is InputEventKey or event is InputEventJoypadButton:
		Perf.input()
	if mode == Mode.BOOT:
		return
	if event is InputEventMouse or event.is_echo():
		return
	for a in InputSetup.ALL:
		if not event.is_action(a):
			continue
		if event is InputEventJoypadMotion:
			if absf((event as InputEventJoypadMotion).axis_value) < 0.5 or _held.has(a):
				continue
		elif not event.is_pressed():
			continue
		_held[a] = Time.get_ticks_msec() + 350
		press(a)
		get_viewport().set_input_as_handled()
		return

func _process(_d: float) -> void:
	Perf.tick()
	if _held.is_empty():
		return
	var now := Time.get_ticks_msec()
	for a: String in _held.keys():
		if not Input.is_action_pressed(a):
			_held.erase(a)
		elif a in InputSetup.REPEATING and now >= int(_held[a]):
			_held[a] = now + 120
			press(a)

## One logical button press, routed to whatever is on top.
func press(action: String) -> void:
	Perf.input()
	match mode:
		Mode.HOME: home.do_action(action)
		Mode.SETTINGS: settings.do_action(action)
		Mode.DIALOG:
			var d := _dialog
			if is_instance_valid(d):
				d.do_action(action)

# --- launching -----------------------------------------------------------------------------
func _on_activated(tile: Dictionary) -> void:
	if mode != Mode.HOME:
		return
	var l: Dictionary = tile.get("launch", {})
	if str(l.get("type", "")) == "internal":
		Sfx.play("select")
		match str(l.get("action", "")):
			"settings":
				mode = Mode.SETTINGS
				settings.open()
			"end_session":
				_confirm_end_session()
		return
	if not backend.is_ready():
		Sfx.play("error")
		return
	_launch_tile = tile
	mode = Mode.LAUNCHING
	Sfx.play("select")
	get_tree().create_timer(0.16).timeout.connect(func() -> void: Sfx.play("launch"))
	Sfx.ambient(false, 0.8)
	launch_view.begin(tile, home.focused_global_center(), Row.BIG)
	create_tween().tween_property(home, "modulate:a", 0.0, 0.3)
	backend.launch(tile)

func _on_progress(_id: String, stage: String, detail: String) -> void:
	if mode == Mode.LAUNCHING:
		launch_view.set_progress(stage, detail)

func _on_failed(id: String, message: String) -> void:
	var title := str(_launch_tile.get("title", "app"))
	for t in catalog.tiles:
		if str(t.get("id", "")) == id:
			title = str(t.get("title", title))
	if mode == Mode.LAUNCHING:
		Sfx.play("error")
		launch_view.dismiss(0.35)
		create_tween().tween_property(home, "modulate:a", 1.0, 0.35)
		Sfx.ambient(true, 2.0)
		_show_dialog("Could not start %s" % title, message, ["OK"], 0, 0, func(_i: int) -> void: _flush_errors())
		return
	if mode == Mode.DORMANT:
		_wake()
	_errors.append([title, message])
	_flush_errors()

## Show queued errors once the UI is idle on the home screen (not mid wake-fade, not in another dialog).
func _flush_errors() -> void:
	if _flushing or _errors.is_empty():
		return
	_flushing = true
	while not _errors.is_empty():
		while mode != Mode.HOME or Time.get_ticks_msec() < _wake_until_ms:
			await get_tree().create_timer(0.1).timeout
		var e: Array = _errors.pop_front()
		Sfx.play("error")
		var done := false
		_show_dialog("Could not start %s" % str(e[0]), str(e[1]), ["OK"], 0, 0, func(_i: int) -> void: done = true)
		while not done:
			await get_tree().create_timer(0.1).timeout
	_flushing = false

func long_error_test() -> void:
	_on_failed("steam", "Found 3 errors:\n1) Failed to parse field 'audio_settings': Failed to parse field 'channel_count': Could not cast to int.   2) Failed to parse field 'video_settings': missing field 'refresh_rate' 3) Unknown key 'foo'")

func _on_foreground(in_launcher: bool) -> void:
	if in_launcher:
		_wake()
	else:
		_go_dormant()

func _dormant_nodes() -> Array[Node]:
	return [bg, home, launch_view, settings]

func _go_dormant() -> void:
	if mode == Mode.DORMANT:
		return
	mode = Mode.DORMANT
	Perf.set_dormant(true)
	bg.set_rendering(false)
	Sfx.pause_all(true)
	for n in _dormant_nodes():
		n.process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)

func _wake() -> void:
	if mode != Mode.DORMANT and mode != Mode.LAUNCHING:
		return
	_wake_until_ms = Time.get_ticks_msec() + 500
	mode = Mode.HOME
	set_process(true)
	for n in _dormant_nodes():
		n.process_mode = Node.PROCESS_MODE_INHERIT
	Perf.set_dormant(false)
	bg.set_rendering(true)
	Sfx.pause_all(false)
	Sfx.ambient(true, 2.0)
	Sfx.play("back")
	home.refresh_state()
	home.modulate.a = 0.0
	create_tween().tween_property(home, "modulate:a", 1.0, 0.4)
	launch_view.dismiss(0.4)

# --- dialogs -------------------------------------------------------------------------------
var _dialog: Dialog

func _show_dialog(title: String, msg: String, labels: Array[String], focus: int, cancel: int, on_done: Callable) -> void:
	var prev := mode
	mode = Mode.DIALOG
	_dialog = Dialog.new()
	add_child(_dialog)
	_dialog.setup(title, msg, labels, focus, cancel)
	_dialog.open()
	_dialog.chosen.connect(func(i: int) -> void:
		mode = Mode.HOME if prev != Mode.DORMANT else Mode.DORMANT
		on_done.call(i))

func _confirm_end_session() -> void:
	_show_dialog("End session?", "This disconnects your stream and closes the launcher.", ["Cancel", "End Session"], 0, 0, func(i: int) -> void:
		if i == 1:
			backend.end_session())

# --- mouse cursor: hidden after 3 s without motion (Wolf pointer is driven by touch) ----------
func _setup_cursor() -> void:
	_last_motion_ms = Time.get_ticks_msec()
	var t := Timer.new()
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.wait_time = 0.5
	t.timeout.connect(func() -> void:
		if not _cursor_hidden and Time.get_ticks_msec() - _last_motion_ms > 3000:
			_cursor_hidden = true
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN)
	add_child(t)
	t.start()

# --- debug hooks (env vars; no effect when unset) ----------------------------------------------
func _state_name() -> String:
	match mode:
		Mode.BOOT: return "boot"
		Mode.LAUNCHING: return "launching"
		Mode.DORMANT: return "dormant"
		_: return "home"

func _setup_debug() -> void:
	_debug_dir = OS.get_environment("VASTATION_DEBUG_SHOTS")
	if _debug_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(_debug_dir)
	var t := Timer.new()
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.ignore_time_scale = true
	t.wait_time = 2.0
	t.timeout.connect(func() -> void:
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(_debug_dir.path_join("live_%02d.png" % _debug_n))
		_debug_n = (_debug_n + 1) % 30
		print("[debug] fps=%d max_fps=%d state=%s" % [Engine.get_frames_per_second(), Engine.max_fps, _state_name()]))
	add_child(t)
	t.start()

func _arm_autolaunch() -> void:
	if _autolaunch != "":
		return
	_autolaunch = OS.get_environment("VASTATION_AUTOLAUNCH")
	if _autolaunch == "":
		return
	_try_autolaunch(4.0)

func _try_autolaunch(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if mode != Mode.HOME:
		_try_autolaunch(1.0)
		return
	for t in catalog.tiles:
		if str(t.get("id", "")) == _autolaunch:
			home.focus_tile(t)
			await get_tree().process_frame
			_on_activated(t)
			return
