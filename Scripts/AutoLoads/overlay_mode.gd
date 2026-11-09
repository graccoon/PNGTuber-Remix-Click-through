extends Node
## Click-through ("overlay") mode for the main window.
##
## While enabled, every mouse click goes to whatever is below the window.
## The window itself can no longer be clicked, so there are always two ways out:
##   1. a global hotkey (works while the window is not focused, via GlobInput),
##   2. a click on the system tray icon.
## The state is intentionally NOT saved: the app always starts with a normal mouse.
##
## Windows: Godot's FLAG_MOUSE_PASSTHROUGH only answers WM_NCHITTEST with HTTRANSPARENT, which
## passes clicks to windows of the same thread and swallows them for other applications.
## Real click-through needs WS_EX_LAYERED | WS_EX_TRANSPARENT, which the small ClickThrough
## GDExtension (addons/click_through, sources in native/click_through) sets on the window.
## Without that extension the mode is refused on Windows instead of swallowing clicks.

signal click_through_changed(enabled: bool)

const ACTION := "toggle_click_through"
const SETTINGS_KEY := "click_through_hotkey"
const DEFAULT_HOTKEY := {
	"keycode": KEY_F10,
	"ctrl": true,
	"alt": true,
	"shift": false,
	"meta": false,
}

var enabled: bool = false
## Set by the hotkey settings button while it waits for a key, so that the
## currently bound hotkey does not toggle the mode in the middle of rebinding.
var capturing: bool = false

var _tray: StatusIndicator = null
var _tray_available: bool = false
## ClickThroughNative instance (Windows only), null when the extension is not loaded.
var _native: Object = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_native()
	# Default binding right away, the saved one is applied once Settings has loaded.
	apply_hotkey()
	_setup_tray()
	# Settings.gd waits 0.1 s before it reads the settings file.
	await get_tree().create_timer(0.3).timeout
	apply_hotkey()


func _process(_delta: float) -> void:
	if capturing:
		return
	if GlobInput.is_action_just_pressed(ACTION):
		toggle()


# --- Click-through ---------------------------------------------------------

func toggle() -> void:
	set_click_through(not enabled)


## Returns true if the window ended up in the requested state.
func set_click_through(on: bool) -> bool:
	if on and not has_exit_path():
		push_warning("OverlayMode: click-through refused, neither the global hotkey nor the tray icon is available.")
		return false

	var actual: bool
	if _native != null:
		var hwnd: int = DisplayServer.window_get_native_handle(
				DisplayServer.WINDOW_HANDLE, get_window().get_window_id())
		_native.call("set_click_through", hwnd, on)
		# Read the real state back instead of assuming that the style was applied.
		actual = _native.call("is_click_through", hwnd)
	elif OS.get_name() == "Windows":
		push_warning("OverlayMode: the ClickThrough extension (addons/click_through) is not loaded, click-through is unavailable on Windows.")
		return false
	else:
		var window := get_window()
		window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, on)
		actual = window.get_flag(Window.FLAG_MOUSE_PASSTHROUGH)
	if actual != enabled:
		enabled = actual
		_update_tray()
		click_through_changed.emit(enabled)
	return actual == on


## Click-through is only allowed when the user has a way back.
func has_exit_path() -> bool:
	var hotkey_ok := str(GlobInput.backend) != "dummy"
	return _tray_available or hotkey_ok


func _setup_native() -> void:
	if OS.get_name() != "Windows" or not ClassDB.class_exists("ClickThroughNative"):
		return
	var native: Object = ClassDB.instantiate("ClickThroughNative")
	if native != null and native.call("is_supported"):
		_native = native


# --- Hotkey ------------------------------------------------------------------

func get_hotkey() -> Dictionary:
	var saved: Variant = Settings.theme_settings.get(SETTINGS_KEY)
	if saved is Dictionary and int(saved.get("keycode", 0)) != 0:
		return saved
	return DEFAULT_HOTKEY.duplicate()


func set_hotkey(hotkey: Dictionary) -> void:
	Settings.theme_settings[SETTINGS_KEY] = hotkey
	Settings.save()
	apply_hotkey()


func reset_hotkey() -> void:
	set_hotkey(DEFAULT_HOTKEY.duplicate())


func hotkey_to_event(hotkey: Dictionary) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = int(hotkey.get("keycode", KEY_F10)) as Key
	event.ctrl_pressed = bool(hotkey.get("ctrl", false))
	event.alt_pressed = bool(hotkey.get("alt", false))
	event.shift_pressed = bool(hotkey.get("shift", false))
	event.meta_pressed = bool(hotkey.get("meta", false))
	return event


func hotkey_text(hotkey: Dictionary = get_hotkey()) -> String:
	return OS.get_keycode_string(hotkey_to_event(hotkey).get_keycode_with_modifiers())


## Puts the stored hotkey into the InputMap, where GlobInput looks for it.
func apply_hotkey() -> void:
	if InputMap.has_action(ACTION):
		InputMap.action_erase_events(ACTION)
	else:
		InputMap.add_action(ACTION)
	InputMap.action_add_event(ACTION, hotkey_to_event(get_hotkey()))


# --- Tray icon ---------------------------------------------------------------

func _setup_tray() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return
	_tray = StatusIndicator.new()
	_tray.icon = load("res://PicklesSurprised.png")
	_tray.pressed.connect(_on_tray_pressed)
	add_child(_tray)
	_tray_available = true
	_update_tray()


func _on_tray_pressed(_mouse_button: int, _mouse_position: Vector2i) -> void:
	toggle()


func _update_tray() -> void:
	if _tray == null:
		return
	var state := "ON" if enabled else "OFF"
	_tray.tooltip = "PNGTube-Remix | %s: %s" % [tr("TR_CLICK_THROUGH"), state]
