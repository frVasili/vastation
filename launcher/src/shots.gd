class_name Shots
extends Node
## Scripted screenshot tour (tools/shots.sh). Deterministic: mock backend, fixed fps, frozen clock.

var m: Control
var out_dir := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _secs(s: float) -> void:
	await _frames(int(round(s * 30.0)))

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("shot ", shot_name, " ", img.get_size())

func _until(cond: Callable, max_secs: float) -> void:
	var n := int(max_secs * 30.0)
	while n > 0 and not cond.call():
		await get_tree().process_frame
		n -= 1

func _run() -> void:
	await _frames(75)
	await _shot("01_boot_towers")
	await _frames(54)
	await _shot("01b_boot_bloom")
	await _frames(21)
	await _shot("02_boot_logo")
	await _frames(38)
	await _shot("02b_boot_to_home")
	await _until(func() -> bool: return m.mode != m.Mode.BOOT, 5.0)
	await _secs(1.5)
	await _shot("03_home_games")
	m.press("ui_right")
	await _secs(0.8)
	await _shot("04_home_games_focus2")
	m.press("ui_left")
	for pair: Array in [[1, "05_home_emulation"], [2, "06_home_media"], [3, "07_home_system"]]:
		m.home.set_category(pair[0] as int)
		await _secs(0.9)
		await _shot(pair[1] as String)
	for c: int in [2, 1, 0, 1]:
		m.home.set_category(c)
		await _frames(1)
	await _secs(0.6)
	await _shot("06b_after_fast_tabs")
	m.home.set_category(0)
	await _secs(0.7)
	m.home.carousel.jump_to(2)
	await _secs(0.6)
	m.press("confirm")
	await _secs(1.7)
	await _shot("08_launching")
	await _until(func() -> bool: return m.mode == m.Mode.DORMANT, 8.0)
	await _until(func() -> bool: return m.mode == m.Mode.HOME, 8.0)
	await _secs(1.0)
	await _shot("09_returned_running")
	m.home.set_category(2)
	await _secs(0.9)
	m.press("confirm")
	await _until(func() -> bool: return m.mode == m.Mode.DIALOG, 5.0)
	await _secs(0.7)
	await _shot("10_error_dialog")
	m.press("confirm")
	await _secs(0.8)
	m.long_error_test()
	await _until(func() -> bool: return m.mode == m.Mode.DIALOG, 3.0)
	await _secs(0.6)
	await _shot("10b_error_long")
	m.press("confirm")
	await _secs(0.8)
	m.home.set_category(3)
	await _secs(0.8)
	m.home.carousel.jump_to(1)
	await _secs(0.6)
	m.press("confirm")
	await _secs(0.9)
	await _shot("11_settings")
	m.press("cancel")
	await _secs(0.8)
	m.home.carousel.jump_to(2)
	await _secs(0.6)
	m.press("confirm")
	await _secs(0.8)
	await _shot("12_end_session_confirm")
	m.press("cancel")
	await _secs(0.6)
	m.apply_theme("plain")
	m.home.set_category(0)
	await _secs(1.2)
	await _shot("13_default_pack_home")
	m.apply_theme("ember")
	await _secs(1.2)
	await _shot("14_theme_ember_home")
	var b: Boot = m.play_boot(4.9)
	await _secs(0.5)
	await _shot("15_theme_ember_boot")
	b.skip()
	await _secs(1.0)
	m.apply_theme("default")
	OS.set_environment("VASTATION_USER_DIR", ProjectSettings.globalize_path("res://test/user_fixture"))
	m.reload_catalog()
	m.home.set_category(m.catalog.categories.size() - 1)
	await _secs(1.2)
	await _shot("16_user_tiles")
	get_tree().quit()
