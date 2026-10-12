class_name WolfAPI
extends Node
## One nonblocking UDS connection per request; separate incremental SSE connection.
signal event(type: String, data: Dictionary)
signal stream_progress(data: Dictionary)
var socket_path := OS.get_environment("WOLF_SOCKET_PATH")
var _sse: StreamPeerUDS
var _sse_buffer := ""
var _sse_headers := false
var _retry_at := 0.0
var _backoff := 1.0
var _last_sse := 0.0
var _events_enabled := false

func fetch(path: String) -> Dictionary:
	return await _request("GET", path, {}, false)

func post(path: String, body: Dictionary) -> Dictionary:
	return await _request("POST", path, body, false)

func pull(image: String) -> Dictionary:
	return await _request("POST", "/docker/images/pull", {"image_name": image}, true)

func _open(method: String, path: String, body: Dictionary) -> StreamPeerUDS:
	var peer := StreamPeerUDS.new()
	if peer.connect_to_host(socket_path) != OK:
		peer.disconnect_from_host()
		return null
	var payload := JSON.stringify(body) if method == "POST" else ""
	var request := "%s /api/v1%s HTTP/1.0\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s" % [method, path, payload.to_utf8_buffer().size(), payload]
	# Partial writes are polled by the request coroutine (and SSE only sends a tiny GET).
	peer.set_meta("out", request.to_utf8_buffer())
	peer.set_meta("sent", 0)
	return peer

func _send(peer: StreamPeerUDS) -> bool:
	if peer.get_status() == StreamPeerUDS.STATUS_CONNECTING:
		return true
	var bytes: PackedByteArray = peer.get_meta("out")
	var sent: int = peer.get_meta("sent")
	if sent < bytes.size():
		var result := peer.put_partial_data(bytes.slice(sent))
		if result[0] != OK:
			return false
		peer.set_meta("sent", sent + result[1])
	return true

func _request(method: String, path: String, body: Dictionary, streaming: bool) -> Dictionary:
	print("[wolf] %s %s" % [method, path.get_slice("?", 0)])
	var peer := _open(method, path, body)
	if peer == null:
		return {"success": false, "error": "Wolf socket unavailable", "http_status": 0}
	var buffer := PackedByteArray()
	var header_done := false
	var length := -1
	var status := 0
	var lines := ""
	var final: Dictionary = {}
	var deadline := Time.get_ticks_msec() + (600000 if streaming else 30000)
	while is_inside_tree() and Time.get_ticks_msec() < deadline:
		peer.poll()
		if not _send(peer):
			break
		var available := peer.get_available_bytes()
		if available > 0:
			var read := peer.get_partial_data(available)
			if read[0] != OK:
				break
			buffer.append_array(read[1])
			if not header_done:
				var header_end := buffer.get_string_from_utf8().find("\r\n\r\n")
				if header_end >= 0:
					var headers := buffer.slice(0, header_end).get_string_from_utf8()
					status = int(headers.get_slice("\n", 0).get_slice(" ", 1))
					for line in headers.split("\r\n"):
						if line.to_lower().begins_with("content-length:"):
							length = int(line.get_slice(":", 1).strip_edges())
					buffer = buffer.slice(header_end + 4)
					header_done = true
			if header_done and streaming:
				lines += buffer.get_string_from_utf8()
				buffer.clear()
				while "\n" in lines:
					var line := lines.get_slice("\n", 0).strip_edges()
					lines = lines.substr(lines.find("\n") + 1)
					var value = JSON.parse_string(line)
					if value is Dictionary:
						if value.has("success") or value.has("error"):
							final = value
						else:
							stream_progress.emit(value)
				if not final.is_empty():
					break
			elif header_done and length >= 0 and buffer.size() >= length:
				break
		if peer.get_status() not in [StreamPeerUDS.STATUS_CONNECTED, StreamPeerUDS.STATUS_CONNECTING]:
			break
		await get_tree().process_frame
	peer.disconnect_from_host()
	if streaming and final.is_empty():
		var value = JSON.parse_string(lines.strip_edges())
		if value is Dictionary:
			final = value
	elif not streaming:
		var value = JSON.parse_string(buffer.get_string_from_utf8()) if header_done else null
		if value is Dictionary:
			final = value
	if final.is_empty():
		final = {"success": false, "error": "Wolf returned an incomplete response"}
	if status < 200 or status >= 300:
		final["success"] = false
		if not final.has("error"):
			final["error"] = "Wolf HTTP %d" % status
	final["http_status"] = status
	return final

func start_events() -> void:
	_events_enabled = true

func _process(_delta: float) -> void:
	if not _events_enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _sse == null:
		if now < _retry_at:
			return
		_sse = _open("GET", "/events", {})
		_sse_buffer = ""
		_sse_headers = false
		_last_sse = now
		if _sse == null:
			_retry_at = now + _backoff
			_backoff = minf(30.0, _backoff * 2.0)
			return
		print("[wolf] GET /events")
	_sse.poll()
	var healthy := _send(_sse)
	var available := _sse.get_available_bytes()
	if available > 0:
		var read := _sse.get_partial_data(available)
		healthy = healthy and read[0] == OK
		_sse_buffer += read[1].get_string_from_utf8()
		_last_sse = now
		if not _sse_headers and "\r\n\r\n" in _sse_buffer:
			healthy = healthy and _sse_buffer.get_slice(" ", 1) == "200"
			_sse_buffer = _sse_buffer.substr(_sse_buffer.find("\r\n\r\n") + 4)
			_sse_headers = true
			_backoff = 1.0
		if _sse_headers:
			_sse_buffer = _sse_buffer.replace("\r\n", "\n")
			while "\n\n" in _sse_buffer:
				var block := _sse_buffer.substr(0, _sse_buffer.find("\n\n"))
				_sse_buffer = _sse_buffer.substr(block.length() + 2)
				var type := ""
				var data := ""
				for line in block.split("\n"):
					if line.begins_with("event:"):
						type = line.substr(6).strip_edges()
					elif line.begins_with("data:"):
						data += line.substr(5).strip_edges() + "\n"
				var value = JSON.parse_string(data) if not data.is_empty() else null
				if not type.is_empty() and value is Dictionary:
					print("[wolf] event " + type)
					event.emit(type, value)
	if not healthy or _sse.get_status() not in [StreamPeerUDS.STATUS_CONNECTED, StreamPeerUDS.STATUS_CONNECTING] or now - _last_sse > 45.0:
		_sse.disconnect_from_host()
		_sse = null
		_retry_at = now + _backoff
		_backoff = minf(30.0, _backoff * 2.0)

func _exit_tree() -> void:
	if _sse != null:
		_sse.disconnect_from_host()
