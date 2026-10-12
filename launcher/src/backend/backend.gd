class_name LauncherBackend
extends Node
## What the UI needs from "the thing that starts apps". Two implementations:
## WolfBackend (talks to Wolf over its unix socket) and MockBackend (screenshots, local runs).
## The UI never talks to Wolf directly.

## The set of running tiles changed (see running_ids()).
signal state_changed
## stage is one of: "preparing", "pulling", "starting", "joined". detail is a short human line or "".
signal launch_progress(tile_id: String, stage: String, detail: String)
signal launch_failed(tile_id: String, message: String)
## false: the stream now shows an app, the launcher is hidden and gets no input (go dormant).
## true: the stream is back on the launcher (app exited, user pressed the return combo, or reconnect).
signal foreground_changed(in_launcher: bool)

## True once the backend can launch things. The UI shows tiles before that, but not as launchable.
func is_ready() -> bool:
	return false

## Human-readable reason while not ready ("" if fine); shown in the status corner.
func status_text() -> String:
	return ""

## Start (or, if it is already running, rejoin) the tile's app and move the stream to it.
## `tile` is a catalog tile dictionary; only tile.id and tile.launch are used.
func launch(_tile: Dictionary) -> void:
	pass

## Stop a running tile's app (it stays in the catalog).
func stop(_tile_id: String) -> void:
	pass

func running_ids() -> Array[String]:
	return []

## { "width": int, "height": int, "refresh": int, "client": String } of the stream, if known.
func session_info() -> Dictionary:
	return {}

## End the whole streaming session (Moonlight returns to its host list).
func end_session() -> void:
	get_tree().quit()
