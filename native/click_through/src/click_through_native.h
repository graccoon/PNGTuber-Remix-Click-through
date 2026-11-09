#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Win32 click-through for a Godot window.
//
// Godot's own WINDOW_FLAG_MOUSE_PASSTHROUGH on Windows only answers WM_NCHITTEST with
// HTTRANSPARENT, which passes clicks to windows of the SAME thread only. To let clicks reach
// other applications the window needs WS_EX_LAYERED | WS_EX_TRANSPARENT, which this class sets.
class ClickThroughNative : public RefCounted {
	GDCLASS(ClickThroughNative, RefCounted)

protected:
	static void _bind_methods();

public:
	// hwnd comes from DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE).
	// Returns true if the window ended up in the requested state.
	bool set_click_through(int64_t p_hwnd, bool p_enabled);
	bool is_click_through(int64_t p_hwnd) const;
	bool is_supported() const;
};

} // namespace godot
