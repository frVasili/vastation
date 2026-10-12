class_name WolfBackend
extends LauncherBackend
const API = preload("res://src/backend/wolf_api.gd")
var api: WolfAPI
var _ready_for_launch := false
var _session: Dictionary = {}
var _profiles: Array = []
var _running: Dictionary = {}
var _launched: Dictionary = {}
var _titles: Dictionary = {}
var _busy: Dictionary = {}
var _stopping: Dictionary = {}
var _joined := ""
var _session_id := OS.get_environment("WOLF_SESSION_ID")
var _revision := 0
var _polling := false
var _poll_elapsed := 0.0
var _return_flag := OS.get_environment("VASTATION_IPC_DIR").path_join("return") if OS.has_environment("VASTATION_IPC_DIR") else ""

func _ready() -> void:
	api = API.new()
	add_child(api)
	api.event.connect(_event)
	_startup()

func is_ready() -> bool:
	return _ready_for_launch

func status_text() -> String:
	return "" if _ready_for_launch else "Connecting to Wolf..."

func running_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _running:
		ids.append(id)
	return ids

func session_info() -> Dictionary:
	return {"width": _session.get("video_width", 0), "height": _session.get("video_height", 0), "refresh": _session.get("video_refresh_rate", 0), "client": _session.get("client_ip", "")}

func _startup() -> void:
	var delay := 1.0
	while is_inside_tree():
		var sessions: Dictionary = await api.fetch("/sessions")
		if sessions.get("success", false):
			for entry in sessions.get("sessions", []):
				if str(entry.get("client_id", "")) == _session_id:
					# Keep only the fields we need; never retain or print stream keys.
					for key in ["video_width", "video_height", "video_refresh_rate", "audio_channel_count"]:
						_session[key] = int(entry.get(key, 0))
					_session["client_ip"] = str(entry.get("client_ip", ""))
					# Godot parses every JSON number as float; Wolf rejects 1000.0 for an int field.
					var settings: Dictionary = entry.get("client_settings", {})
					for key in ["run_uid", "run_gid"]:
						if settings.has(key):
							settings[key] = int(settings[key])
					_session["client_settings"] = settings
		if not _session.is_empty():
			var profiles: Dictionary = await api.fetch("/profiles")
			if profiles.get("success", false):
				_profiles = profiles.get("profiles", [])
				if await _refresh():
					_ready_for_launch = true
					api.start_events()
					state_changed.emit()
					return
		await get_tree().create_timer(delay).timeout
		delay = minf(delay * 2.0, 30.0)

func launch(tile: Dictionary) -> void:
	var id := str(tile.get("id", ""))
	if not _busy.is_empty():
		launch_failed.emit(id, "Another app is starting")
		return
	_revision += 1
	_busy[id] = true
	await _launch(tile)
	_busy.erase(id)

func _launch(tile: Dictionary) -> void:
	var id := str(tile.get("id", ""))
	var recipe: Dictionary = tile.get("launch", {})
	_titles[id] = tile.get("title", id)
	if not is_ready():
		launch_failed.emit(id, "Connecting to Wolf...")
		return
	var kind := str(recipe.get("type", ""))
	var app: Dictionary = {}
	var profile := str(recipe.get("profile", "user"))
	if kind == "wolf_runner":
		# A complete runner definition in the tile itself: nothing has to exist in Wolf's config.
		var inline: Dictionary = recipe.get("runner", {}).duplicate(true)
		if str(inline.get("image", "")).is_empty() or str(inline.get("name", "")).is_empty():
			launch_failed.emit(id, "This tile's runner needs at least a name and an image")
			return
		inline["type"] = "docker"
		for key in ["env", "mounts", "devices", "ports"]:
			if not inline.has(key):
				inline[key] = []
		app = {"runner": inline}
	elif kind == "wolf_app":
		for entry in _profiles:
			if entry.get("id") == profile:
				for candidate in entry.get("apps", []):
					if str(candidate.get("title", "")).strip_edges().to_lower() == str(recipe.get("app", "")).strip_edges().to_lower():
						app = candidate
		if app.is_empty():
			launch_failed.emit(id, "Wolf app '%s' was not found in profile '%s'" % [recipe.get("app", ""), profile])
			return
	else:
		launch_failed.emit(id, "Unsupported launch recipe")
		return
	var lobby_id := str(_running.get(id, ""))
	if lobby_id.is_empty():
		launch_progress.emit(id, "preparing", "")
		var runner: Dictionary = app.get("runner", {}).duplicate(true)
		for pair in [["runner_name", "name"], ["image", "image"]]:
			if recipe.has(pair[0]):
				runner[pair[1]] = recipe[pair[0]]
		var env: Array = runner.get("env", []).duplicate()
		for override in recipe.get("env", []):
			var key: String = str(override).get_slice("=", 0)
			for index in range(env.size() - 1, -1, -1):
				if str(env[index]).get_slice("=", 0) == key:
					env.remove_at(index)
			env.append(override)
		# The GoW images default to Europe/London: hand our own timezone to every app.
		var tz := OS.get_environment("TZ")
		if not tz.is_empty() and not env.any(func(e): return str(e).begins_with("TZ=")):
			env.append("TZ=" + tz)
		runner["env"] = env
		# Deployment-wide extra mounts (our top bar with the HOME button, the return-request folder).
		var mounts: Array = runner.get("mounts", []).duplicate()
		for mount in OS.get_environment("VASTATION_APP_MOUNTS").split(";", false):
			if mount not in mounts:
				mounts.append(mount)
		runner["mounts"] = mounts
		var image := str(runner.get("image", ""))
		var inspected: Dictionary = await api.fetch("/docker/images/inspect?image_name=" + image.uri_encode())
		if inspected.get("http_status") == 404:
			launch_progress.emit(id, "pulling", "")
			var layers := {}
			var progress := func(data: Dictionary):
				layers[str(data.get("layer_id", ""))] = [float(data.get("current_progress", 0)), float(data.get("total", 0))]
				var done := 0.0
				for layer in layers.values():
					done += layer[0]
				# Layer totals only appear as each layer starts, so a percentage would jump around.
				launch_progress.emit(id, "pulling", "Downloading, first start only (%.1f GB so far)" % (done / 1e9))
			api.stream_progress.connect(progress)
			var pulled: Dictionary = await api.pull(image)
			api.stream_progress.disconnect(progress)
			if not _check(id, pulled):
				return
		elif not _check(id, inspected):
			return
		launch_progress.emit(id, "starting", "")
		var render_node := str(app.get("render_node", _default_render_node()))
		var created: Dictionary = await api.post("/lobbies/create", {
			"profile_id": profile, "name": "vs:" + id, "multi_user": false, "stop_when_everyone_leaves": false,
			"runner_state_folder": recipe.get("state_folder", "profile-data/%s/%s" % [profile, runner.get("name", "")]), "runner": runner,
			"video_settings": {"width": _session.video_width, "height": _session.video_height, "refresh_rate": _session.video_refresh_rate,
				"wayland_render_node": render_node, "runner_render_node": render_node, "video_producer_buffer_caps": OS.get_environment("WOLF_VIDEO_BUFFER_CAPS")},
			"audio_settings": {"channel_count": _session.audio_channel_count}, "client_settings": _session.get("client_settings", {})})
		if not _check(id, created):
			return
		lobby_id = str(created.get("lobby_id", ""))
		_running[id] = lobby_id
		_launched[id] = Time.get_ticks_msec()
		state_changed.emit()
	var joined: Dictionary = await api.post("/lobbies/join", {"lobby_id": lobby_id, "moonlight_session_id": _session_id})
	if not _check(id, joined):
		return
	if not _return_flag.is_empty() and FileAccess.file_exists(_return_flag):
		DirAccess.remove_absolute(_return_flag)
	_joined = lobby_id
	launch_progress.emit(id, "joined", "")
	state_changed.emit()
	foreground_changed.emit(false)
	# A Leave/Stop event may have been handled while the join answer was in flight: reconcile now
	# (not in 5 s) so the UI can never stay dormant while the stream is back on the launcher.
	_revision += 1
	_poll_elapsed = 0.0
	await _refresh()

## Tiles with an inline runner have no render node of their own: use the one Wolf's configured apps use.
func _default_render_node() -> String:
	for entry in _profiles:
		for candidate in entry.get("apps", []):
			if not str(candidate.get("render_node", "")).is_empty():
				return str(candidate.render_node)
	return "/dev/dri/renderD128"

func _check(id: String, response: Dictionary) -> bool:
	if not response.get("success", true):
		launch_failed.emit(id, str(response.get("error", "Wolf request failed")))
		return false
	return true

func stop(tile_id: String) -> void:
	if _running.has(tile_id):
		_revision += 1
		_stopping[tile_id] = true
		var response: Dictionary = await api.post("/lobbies/stop", {"lobby_id": _running[tile_id]})
		if not _check(tile_id, response):
			_stopping.erase(tile_id)
		else:
			_removed(tile_id)

func end_session() -> void:
	await api.post("/sessions/stop", {"session_id": _session_id})
	get_tree().quit()

func _returned() -> void:
	if not _joined.is_empty():
		_joined = ""
		foreground_changed.emit(true)

func _removed(id: String) -> void:
	if not _running.has(id):
		return
	if str(_running[id]) == _joined:
		_returned()
	_revision += 1
	_running.erase(id)
	if _launched.has(id) and not _stopping.has(id) and Time.get_ticks_msec() - int(_launched[id]) < 20000:
		launch_failed.emit(id, "%s closed right after starting" % _titles.get(id, id))
	_launched.erase(id)
	_stopping.erase(id)
	state_changed.emit()

func _event(type: String, data: Dictionary) -> void:
	if type.ends_with("LeaveLobbyEvent") and str(data.get("moonlight_session_id", "")) == _session_id and str(data.get("lobby_id", "")) == _joined:
		_returned()
	elif type.ends_with("JoinLobbyEvent") and str(data.get("moonlight_session_id", "")) == _session_id:
		_joined = str(data.get("lobby_id", ""))
	elif type.ends_with("StopLobbyEvent"):
		for id in _running.keys():
			if _running[id] == str(data.get("lobby_id", "")):
				_removed(id)

## An app can ask for the stream to go back to the launcher by creating this file (the HOME button of
## our top bar does). Apps never get Wolf's API socket; this request is all they can make.
func _check_return_request() -> void:
	if _joined.is_empty() or _return_flag.is_empty() or not FileAccess.file_exists(_return_flag):
		return
	DirAccess.remove_absolute(_return_flag)
	print("[wolf] return requested by the app")
	api.post("/lobbies/leave", {"lobby_id": _joined, "moonlight_session_id": _session_id})

func _process(delta: float) -> void:
	_check_return_request()
	_poll_elapsed += delta
	if _ready_for_launch and _busy.is_empty() and not _polling and _poll_elapsed >= 5.0:
		_poll_elapsed = 0.0
		_polling = true
		await _refresh()
		_polling = false

func _refresh() -> bool:
	var revision := _revision
	var response: Dictionary = await api.fetch("/lobbies")
	if not response.get("success", false):
		return false
	if revision != _revision:
		return true # A launch/stop changed state while this snapshot was in flight.
	var found: Dictionary = {}
	var connected := ""
	for lobby in response.get("lobbies", []):
		var name := str(lobby.get("name", ""))
		if name.begins_with("vs:"):
			found[name.substr(3)] = str(lobby.id)
		if _session_id in lobby.get("connected_sessions", []):
			connected = str(lobby.id)
	for id in _running.keys():
		if not found.has(id):
			_removed(id)
	if connected.is_empty():
		_returned()
	else:
		_joined = connected
	if _running != found:
		_running = found
		state_changed.emit()
	return true
