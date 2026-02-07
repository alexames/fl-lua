# FL-Lua

VST3 plugin that embeds a Lua 5.5 scripting engine for procedural MIDI generation in FL Studio.

Write Lua scripts directly in the built-in code editor to generate MIDI notes, arpeggios, rhythms, and control changes — all synchronized to the DAW transport. Includes the [musica](https://github.com/alexames) music theory library for working with scales, chords, modes, and more.

## Installation

### Quick Install

1. Build the project (see [Building](#building) below), or locate the pre-built bundle at:
   ```
   build\VST3\Release\FL-Lua.vst3\
   ```

2. Copy the entire `FL-Lua.vst3` folder to your VST3 plugin directory:
   ```
   C:\Program Files\Common Files\VST3\
   ```
   You should end up with:
   ```
   C:\Program Files\Common Files\VST3\FL-Lua.vst3\
     Contents\
       x86_64-win\FL-Lua.vst3    (the plugin DLL)
       Resources\
         lua_libs\                (bundled Lua libraries)
         moduleinfo.json
   ```

3. Open FL Studio, then scan for new plugins:
   - Go to **Options > Manage plugins**
   - Click **Start scan** (or **Find plugins**)
   - FL-Lua should appear under **Installed > VST3**

### Using FL-Lua in FL Studio

FL-Lua outputs MIDI events via its VST3 event output bus. To hear the generated notes, route them to an instrument:

#### Method 1: Patcher (Recommended)

1. Open the **Channel Rack** and add **Patcher** as a generator
2. Inside Patcher, right-click the canvas and add:
   - **FL-Lua** (under VST3)
   - An instrument (e.g., Sytrus, FLEX, or any VST synth)
3. Connect **FL-Lua**'s output to the instrument's input
4. Write or load a Lua script in FL-Lua's editor
5. Press **Run** (or Ctrl+Enter) and hit Play in the transport

#### Method 2: MIDI Routing

1. Add FL-Lua as a generator in the Channel Rack
2. Use FL Studio's internal MIDI routing to send FL-Lua's output to another channel's instrument

## Building

### Prerequisites

- **CMake** 3.21+
- **Visual Studio 2022** with C++ desktop development workload
- **Git** (for submodules and vcpkg)

### Build Steps

```bash
git clone --recursive <repo-url> fl-lua
cd fl-lua
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

vcpkg is bootstrapped automatically by CMake. Dependencies (Lua 5.5, ImGui, spdlog, etc.) are fetched and built on first configure.

The built plugin bundle will be at `build\VST3\Release\FL-Lua.vst3\`.

## Lua Scripting API

### Callbacks

Define these global functions in your script — the plugin calls them automatically:

```lua
-- Called once per beat (quarter note) while the transport is playing
function on_beat(ctx, beat)
    ctx.note(60, 100, 0.5)  -- Play middle C for half a beat
end

-- Called every audio process block (~1-6ms) while the transport is playing
function process(ctx)
    -- Fine-grained event generation
end
```

### Context Functions

| Function | Description |
|---|---|
| `ctx.note(pitch, velocity, duration_beats)` | Play a note with automatic note-off after duration |
| `ctx.note_on(pitch, velocity [, channel])` | Send MIDI Note On (channel defaults to 0) |
| `ctx.note_off(pitch [, channel])` | Send MIDI Note Off |
| `ctx.cc(controller, value [, channel])` | Send MIDI Control Change |
| `ctx.pitch_bend(value [, channel])` | Send Pitch Bend (-8192 to 8191) |
| `ctx.log(message)` | Print to the plugin console |

### Context Properties (read-only)

| Property | Description |
|---|---|
| `ctx.beat` | Current beat position (float, in quarter notes) |
| `ctx.bar` | Current bar number (int) |
| `ctx.tempo` | Current BPM (float) |
| `ctx.playing` | Transport playing state (boolean) |
| `ctx.sample_rate` | Sample rate in Hz (float) |
| `ctx.time_sig_num` | Time signature numerator |
| `ctx.time_sig_den` | Time signature denominator |

### Bundled Libraries

Scripts can `require` the bundled Lua libraries:

```lua
local musica = require 'musica'

local scale = musica.Scale(musica.Pitch.c4, musica.Mode.minor)

function on_beat(ctx, beat)
    local degree = (beat % 7) + 1
    local pitch = scale:to_pitch(degree)
    ctx.note(pitch:midi(), 80, 0.5)
end
```

- **musica** — Music theory: pitches, scales, chords, modes, rhythm, figures
- **llx** — Lua foundation: classes, enums, types, functional programming
- **lua-midi** — MIDI file reading/writing

## Example Scripts

Example scripts are included in `scripts/examples/`:

- **hello_note.lua** — Plays middle C every beat
- **arpeggiator.lua** — Arpeggiates through a C major chord
- **scale_walk.lua** — Walks up and down a C minor scale
- **euclidean.lua** — Euclidean rhythm generator (5 hits over 8 steps)

Load them via **File > Open** in the plugin editor.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Ctrl+Enter | Run script |
| Ctrl+O | Open Lua file |
| Ctrl+S | Save Lua file |

## Architecture

- **Processor** (audio thread): Runs compiled Lua callbacks, generates MIDI events, tracks transport state
- **Controller** (UI thread): ImGui editor with syntax highlighting, compiles scripts, file I/O
- **Communication**: Lock-free queues (moodycamel::ReaderWriterQueue) for script hot-swap and log messages

### Sandboxing

Scripts run in a sandboxed Lua environment:
- Only safe standard libraries are loaded (no `io`, `os`, or `debug`)
- `require` only resolves bundled libraries (no arbitrary DLL loading)
- An instruction count hook prevents runaway scripts

## Technology

- **Lua 5.5** via custom vcpkg registry
- **VST3 SDK** (Steinberg)
- **Dear ImGui** with DX11 backend
- **ImGuiColorTextEdit** for code editing
- **luawrapper** for C++/Lua bindings
- **moodycamel::ReaderWriterQueue** for lock-free messaging
- **spdlog** / **fmt** for logging
