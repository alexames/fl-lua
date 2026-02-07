#pragma once

#include <readerwriterqueue/readerwriterqueue.h>

#include <string>

#include "midi_event.hpp"

namespace FLLua {

// Lock-free queue for MIDI events (Lua thread → audio thread)
using MidiEventQueue = moodycamel::ReaderWriterQueue<MidiEvent>;

// Lock-free queue for log messages (audio thread → UI thread)
using LogQueue = moodycamel::ReaderWriterQueue<std::string>;

// Message to swap script in the processor
struct ScriptSwapMessage {
  std::string source;
};
using ScriptQueue = moodycamel::ReaderWriterQueue<ScriptSwapMessage>;

}  // namespace FLLua
