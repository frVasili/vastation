class_name InputSetup
extends RefCounted
## InputMap actions: controller, keyboard. (Touch arrives as mouse events and is handled by the controls.)

const REPEATING: Array[String] = ["ui_left", "ui_right", "ui_up", "ui_down"]
const ALL: Array[String] = ["ui_left", "ui_right", "ui_up", "ui_down", "confirm", "cancel", "tab_prev", "tab_next", "options"]

static func setup() -> void:
	_action("ui_left", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("ui_right", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("ui_up", [KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("ui_down", [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A], [])
	_action("cancel", [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B], [])
	_action("tab_prev", [KEY_Q, KEY_PAGEUP], [JOY_BUTTON_LEFT_SHOULDER], [])
	_action("tab_next", [KEY_E, KEY_PAGEDOWN], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_action("options", [KEY_TAB], [JOY_BUTTON_Y], [])

static func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.5)
	for k: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(action, e)
	for b: int in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b as JoyButton
		InputMap.action_add_event(action, e)
	for a: Array in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = (a[0] as int) as JoyAxis
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
