#pragma once

#include "events/event_queue.hpp"
#include "transport/transport.hpp"

struct lua_State;

namespace FLLua {

// Context object shared between C++ and Lua
struct PluginContext {
  MidiEventQueue* eventQueue = nullptr;
  LogQueue* logQueue = nullptr;
  TransportState transport;
  std::vector<ScheduledNoteOff>* scheduledNoteOffs = nullptr;
};

// Register the ctx API table in the given Lua state
void registerPluginAPI(lua_State* L, PluginContext* ctx);

// Update the ctx read-only fields (beat, bar, tempo, etc.)
void updateContextFields(lua_State* L, const PluginContext* ctx);

}  // namespace FLLua
