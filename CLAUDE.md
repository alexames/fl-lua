# FL-Lua

VST3 plugin that embeds Lua 5.5 with a built-in ImGui code editor for procedural MIDI generation in FL Studio. Users write Lua scripts that generate MIDI notes synchronized to the DAW transport, routed to downstream instruments via Patcher.

## Architecture

**Threading model:**
- **Audio thread** (Processor): Runs Lua callbacks (`on_beat`, `process`), generates MIDI events, reads transport state
- **UI thread** (Controller + PlugView): ImGui editor, compiles scripts, displays console
- **Communication**: Lock-free `moodycamel::ReaderWriterQueue` for events/logs, VST3 `IMessage` for script transfer

**Key components:**
- `src/plugin/processor.cpp` — Audio processing, Lua execution, MIDI output via VST3 event bus
- `src/plugin/controller.cpp` — Script/log message relay between processor and UI
- `src/plugin/plugview.cpp` — Win32 child window, DX11 + ImGui rendering at 60fps
- `src/gui/editor.cpp` — Code editor (ImGuiColorTextEdit) with menu bar, console, status bar
- `src/lua/engine.cpp` — Lua state lifecycle, script compilation, callback invocation
- `src/lua/api.cpp` — `ctx` table exposed to Lua (note/cc/log functions, transport properties)
- `src/lua/sandbox.cpp` — Selective stdlib loading (no io/os/debug), restricted package.path

**Lua API exposed to scripts:**
- Functions: `ctx.note(pitch, vel, duration)`, `ctx.note_on()`, `ctx.note_off()`, `ctx.cc()`, `ctx.pitch_bend()`, `ctx.log()`
- Properties: `ctx.beat`, `ctx.bar`, `ctx.tempo`, `ctx.playing`, `ctx.sample_rate`, `ctx.time_sig_num`, `ctx.time_sig_den`

## Bundled Lua libraries

Copied into the `.vst3` bundle at `Contents/Resources/lua_libs/`:
- **llx** — Foundation: classes, enums, types, functional programming
- **musica** — Music theory: pitches, scales, chords, modes, rhythm, generation
- **lua-midi** — MIDI file reading/writing

## Build

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target FL-Lua
```

vcpkg bootstraps automatically via `cmake/vcpkg_bootstrap.cmake`. Dependencies come from the default vcpkg registry and a custom registry at `https://github.com/alexames/vcpkg-registry` (for lua55, luawrapper, imgui-color-text-edit, vst3sdk).

**Install:**
```sh
cmake --install build --config Release --prefix install
```

Output: `install/FL-Lua.vst3/` (copy to `C:\Program Files\Common Files\VST3\`)

## Code style

Before committing, format all changed files:

```sh
clang-format -i <changed .cpp/.hpp files>
stylua <changed .lua files>
```

- C++: Google style (`.clang-format`)
- Lua: 80 columns, 2-space indent, single quotes (`.stylua.toml`)

## CI/CD

`.github/workflows/ci.yml` runs on push/PR to main:
1. **Code Style** — clang-format on `src/`, StyLua on `scripts/`
2. **Build** — Windows build + bundle verification (checks lua_libs are present)
3. **Release** — On push to main: zips artifact, uploads as `latest` pre-release on GitHub
