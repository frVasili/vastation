extends SceneTree
const Backend = preload("res://src/backend/wolf_backend.gd")
var backend: WolfBackend
var joined := 0
var returned := 0
var failures: Array[String] = []
var stages: Array[String] = []
var tile := {"id": "steam", "title": "Steam", "launch": {"type": "wolf_app", "profile": "user", "app": " steam "}}

func _initialize() -> void:
	_run.call_deferred()

func _assert(value: bool, message: String) -> void:
	if not value:
		printerr("TEST FAILED: " + message)
		quit(1)

func _wait(predicate: Callable) -> void:
	var limit := Time.get_ticks_msec() + 8000
	while not predicate.call() and Time.get_ticks_msec() < limit:
		await process_frame
	_assert(predicate.call(), "timed out waiting for state")

func _run() -> void:
	backend = Backend.new()
	root.add_child(backend)
	backend.foreground_changed.connect(func(front: bool):
		if front: returned += 1
		else: joined += 1)
	backend.launch_failed.connect(func(_id: String, message: String): failures.append(message))
	backend.launch_progress.connect(func(_id: String, stage: String, _detail: String): stages.append(stage))
	await _wait(func(): return backend.is_ready())
	_assert(backend.session_info().refresh == 60, "session information")
	await create_timer(.1).timeout
	await backend.launch(tile)
	_assert(joined == 1 and backend.running_ids() == ["steam"], "launch joined")
	_assert("pulling" in stages and "starting" in stages, "pull stages")
	await backend.api.post("/control", {"action": "return"})
	await _wait(func(): return returned == 1)
	_assert(backend.running_ids() == ["steam"], "return retains running lobby")
	await backend.launch(tile)
	_assert(joined == 2, "rejoin")
	await backend.stop("steam")
	await _wait(func(): return backend.running_ids().is_empty())
	_assert(failures.is_empty(), "intentional stop must not report crash")
	await backend.launch({"id": "missing", "launch": {"type": "wolf_app", "app": "Missing"}})
	_assert(failures.size() == 1 and "not found" in failures[0], "missing app error")
	await backend.launch(tile)
	await backend.api.post("/control", {"action": "exit"})
	await _wait(func(): return failures.size() == 2)
	_assert("closed right after starting" in failures[1], "early app exit")
	backend.queue_free()
	await process_frame
	print("BACKEND TEST PASSED")
	quit(0)
