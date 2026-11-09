#include "click_through_native.h"

#include <godot_cpp/core/class_db.hpp>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

using namespace godot;

void ClickThroughNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_click_through", "hwnd", "enabled"), &ClickThroughNative::set_click_through);
	ClassDB::bind_method(D_METHOD("is_click_through", "hwnd"), &ClickThroughNative::is_click_through);
	ClassDB::bind_method(D_METHOD("is_supported"), &ClickThroughNative::is_supported);
}

#ifdef _WIN32

namespace {
constexpr LONG_PTR CLICK_THROUGH_BITS = WS_EX_LAYERED | WS_EX_TRANSPARENT;
// Remembers whether WS_EX_LAYERED was added by us, so that turning the mode off restores
// the exact style Godot created the window with.
bool g_layered_added_by_us = false;

HWND to_hwnd(int64_t p_hwnd) {
	return reinterpret_cast<HWND>(static_cast<intptr_t>(p_hwnd));
}
} // namespace

bool ClickThroughNative::is_supported() const {
	return true;
}

bool ClickThroughNative::is_click_through(int64_t p_hwnd) const {
	HWND hwnd = to_hwnd(p_hwnd);
	if (hwnd == nullptr || !IsWindow(hwnd)) {
		return false;
	}
	LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	return (ex & CLICK_THROUGH_BITS) == CLICK_THROUGH_BITS;
}

bool ClickThroughNative::set_click_through(int64_t p_hwnd, bool p_enabled) {
	HWND hwnd = to_hwnd(p_hwnd);
	if (hwnd == nullptr || !IsWindow(hwnd)) {
		return false;
	}

	LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	if (p_enabled) {
		if (!(ex & WS_EX_LAYERED)) {
			g_layered_added_by_us = true;
		}
		ex |= CLICK_THROUGH_BITS;
	} else {
		ex &= ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT);
		if (g_layered_added_by_us) {
			ex &= ~static_cast<LONG_PTR>(WS_EX_LAYERED);
			g_layered_added_by_us = false;
		}
	}

	SetLastError(0);
	SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex);
	if (GetLastError() != 0) {
		return false;
	}

	if (p_enabled) {
		// A layered window is not drawn until its attributes are set. Fully opaque keeps the
		// per-pixel alpha that Godot's transparent window already provides.
		SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
	}
	// Apply the new extended style right away.
	SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
			SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
	RedrawWindow(hwnd, nullptr, nullptr, RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW);

	return is_click_through(p_hwnd) == p_enabled;
}

#else // not Windows: the class still exists so scripts can ask is_supported().

bool ClickThroughNative::is_supported() const {
	return false;
}

bool ClickThroughNative::is_click_through(int64_t) const {
	return false;
}

bool ClickThroughNative::set_click_through(int64_t, bool) {
	return false;
}

#endif
