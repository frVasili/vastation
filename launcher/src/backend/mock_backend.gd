class_name MockBackend
extends LauncherBackend
## Fake backend for screenshots and local runs. See the brief: kodi fails, lutris "pulls".

var _ready_flag := false
var _running: Array[String] = []

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_ready_flag = true
	state_changed.emit()

func is_ready() -> bool:
	return _ready_flag

func status_text() -> String:
	return "" if _ready_flag else "Connecting to Wolf..."

func launch(tile: Dictionary) -> void:
	var id := str(tile.get("id", ""))
	launch_progress.emit(id, "preparing", "")
	await get_tree().create_timer(0.4).timeout
	if id == "kodi":
		launch_failed.emit(id, "Image pull failed: connection timed out")
		return
	if id == "lutris":
		launch_progress.emit(id, "pulling", "Downloading Lutris (first start can take a few minutes)")
		await get_tree().create_timer(2.0).timeout
	launch_progress.emit(id, "starting", "")
	await get_tree().create_timer(0.6).timeout
	launch_progress.emit(id, "joined", "")
	if id not in _running:
		_running.append(id)
	state_changed.emit()
	await get_tree().create_timer(0.8).timeout
	foreground_changed.emit(false)
	await get_tree().create_timer(3.0).timeout
	foreground_changed.emit(true)

func stop(tile_id: String) -> void:
	_running.erase(tile_id)
	state_changed.emit()

func running_ids() -> Array[String]:
	return _running

func session_info() -> Dictionary:
	return {"width": 1280, "height": 720, "refresh": 60, "client": "Mock"}

func end_session() -> void:
	print("mock: end_session")
