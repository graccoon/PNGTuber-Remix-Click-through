# ClickThrough GDExtension

Small native helper that gives PNGTuber-Remix real click-through on Windows.

Godot's `FLAG_MOUSE_PASSTHROUGH` only answers `WM_NCHITTEST` with `HTTRANSPARENT`, which passes
clicks to windows of the same thread and drops them for other applications. This extension sets
`WS_EX_LAYERED | WS_EX_TRANSPARENT` on the window instead (and restores the original style when
turned off). It exposes one class, `ClickThroughNative`, with:

- `set_click_through(hwnd: int, enabled: bool) -> bool`
- `is_click_through(hwnd: int) -> bool`
- `is_supported() -> bool` (true only in the Windows build)

`Scripts/AutoLoads/overlay_mode.gd` loads it dynamically (`ClassDB.instantiate`), so the project
still runs on platforms where the library is not present.

## Rebuilding the DLL

Needs Python, SCons and a MinGW-w64 cross compiler (or MSVC on Windows) and godot-cpp 4.5.

```bash
git clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git native/godot-cpp
cd native/click_through
GODOT_CPP=../godot-cpp scons platform=windows arch=x86_64 target=template_release \
      use_mingw=yes build_profile=build_profile.json
```

The library is written to `addons/click_through/bin/`. `build_profile.json` limits godot-cpp to the
few classes it needs, which keeps the build short. The built DLL was compiled with MinGW-w64
(GCC 13, static libgcc/libstdc++) and only depends on `KERNEL32.dll`, `USER32.dll` and `msvcrt.dll`.
