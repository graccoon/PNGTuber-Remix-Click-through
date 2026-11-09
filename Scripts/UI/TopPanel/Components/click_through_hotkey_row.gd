extends HBoxContainer
## Settings row: shows the click-through hotkey, lets the user rebind or reset it.
## Click the key button, then press the new combination. Escape cancels.

var _capture: Button
var _reset: Button


func _ready() -> void:
	_capture = Button.new()
	_capture.toggle_mode = true
	_capture.theme_type_variation = "RemapButton"
	_capture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capture.toggled.connect(_on_capture_toggled)
	add_child(_capture)

	_reset = Button.new()
	_reset.pressed.connect(_on_reset_pressed)
	add_child(_reset)

	set_process_input(false)
	_refresh()


func _exit_tree() -> void:
	# Never leave the global hotkey blocked if the settings window is closed mid-capture.
	OverlayMode.capturing = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _capture != null:
		_refresh()


func _refresh() -> void:
	_reset.text = tr("TR_CLICK_THROUGH_HOTKEY_RESET")
	if _capture.button_pressed:
		_capture.text = tr("TR_AWAITING_INPUT")
	else:
		_capture.text = OverlayMode.hotkey_text()


func _on_capture_toggled(pressed: bool) -> void:
	OverlayMode.capturing = pressed
	set_process_input(pressed)
	if pressed:
		_capture.release_focus()
	_refresh()


func _on_reset_pressed() -> void:
	_capture.button_pressed = false
	OverlayMode.reset_hotkey()
	_refresh()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()

	var key := key_event.keycode
	# Wait for the actual key, a modifier alone is not a hotkey.
	if key == KEY_NONE or key == KEY_CTRL or key == KEY_ALT or key == KEY_SHIFT or key == KEY_META:
		return

	var has_modifier := key_event.ctrl_pressed or key_event.alt_pressed \
			or key_event.shift_pressed or key_event.meta_pressed
	if key == KEY_ESCAPE and not has_modifier:
		_capture.button_pressed = false
		return
	# A plain letter or digit would toggle the mode while typing, require a modifier for those.
	if not has_modifier and (key & KEY_SPECIAL) == 0:
		_capture.text = tr("TR_CLICK_THROUGH_NEEDS_MODIFIER")
		return

	OverlayMode.set_hotkey({
		"keycode": int(key),
		"ctrl": key_event.ctrl_pressed,
		"alt": key_event.alt_pressed,
		"shift": key_event.shift_pressed,
		"meta": key_event.meta_pressed,
	})
	_capture.button_pressed = false
