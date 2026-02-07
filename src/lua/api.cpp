#include "api.hpp"

#include <fmt/format.h>

#include <string>

extern "C" {
#include <lauxlib.h>
#include <lua.h>
}

namespace FLLua {

static const char* kContextRegistryKey = "FLLua_PluginContext";

static PluginContext* getContext(lua_State* L) {
  lua_getfield(L, LUA_REGISTRYINDEX, kContextRegistryKey);
  auto* ctx = static_cast<PluginContext*>(lua_touserdata(L, -1));
  lua_pop(L, 1);
  return ctx;
}

// ctx.note_on(note, velocity, channel?)
static int ctx_note_on(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->eventQueue) return 0;

  uint8_t note = static_cast<uint8_t>(luaL_checkinteger(L, 1));
  uint8_t velocity = static_cast<uint8_t>(luaL_checkinteger(L, 2));
  uint8_t channel = static_cast<uint8_t>(luaL_optinteger(L, 3, 0));

  ctx->eventQueue->enqueue(NoteOn{note, velocity, channel, 0});
  return 0;
}

// ctx.note_off(note, channel?)
static int ctx_note_off(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->eventQueue) return 0;

  uint8_t note = static_cast<uint8_t>(luaL_checkinteger(L, 1));
  uint8_t channel = static_cast<uint8_t>(luaL_optinteger(L, 2, 0));

  ctx->eventQueue->enqueue(NoteOff{note, channel, 0});
  return 0;
}

// ctx.note(note, velocity, duration_beats)
static int ctx_note(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->eventQueue) return 0;

  uint8_t note = static_cast<uint8_t>(luaL_checkinteger(L, 1));
  uint8_t velocity = static_cast<uint8_t>(luaL_checkinteger(L, 2));
  double duration = luaL_checknumber(L, 3);
  uint8_t channel = static_cast<uint8_t>(luaL_optinteger(L, 4, 0));

  ctx->eventQueue->enqueue(NoteOn{note, velocity, channel, 0});

  if (ctx->scheduledNoteOffs) {
    double endBeat = ctx->transport.beat + duration;
    ctx->scheduledNoteOffs->push_back(ScheduledNoteOff{note, channel, endBeat});
  }
  return 0;
}

// ctx.cc(controller, value, channel?)
static int ctx_cc(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->eventQueue) return 0;

  uint8_t controller = static_cast<uint8_t>(luaL_checkinteger(L, 1));
  uint8_t value = static_cast<uint8_t>(luaL_checkinteger(L, 2));
  uint8_t channel = static_cast<uint8_t>(luaL_optinteger(L, 3, 0));

  ctx->eventQueue->enqueue(CC{controller, value, channel, 0});
  return 0;
}

// ctx.pitch_bend(value, channel?)
static int ctx_pitch_bend(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->eventQueue) return 0;

  int16_t value = static_cast<int16_t>(luaL_checkinteger(L, 1));
  uint8_t channel = static_cast<uint8_t>(luaL_optinteger(L, 2, 0));

  ctx->eventQueue->enqueue(PitchBend{value, channel, 0});
  return 0;
}

// ctx.log(message)
static int ctx_log(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->logQueue) return 0;

  const char* msg = luaL_checkstring(L, 1);
  ctx->logQueue->enqueue(std::string(msg));
  return 0;
}

// __index metamethod for ctx to provide read-only fields
static int ctx_index(lua_State* L) {
  auto* ctx = getContext(L);
  const char* key = luaL_checkstring(L, 2);

  if (!ctx) return 0;

  if (strcmp(key, "beat") == 0) {
    lua_pushnumber(L, ctx->transport.beat);
    return 1;
  }
  if (strcmp(key, "bar") == 0) {
    lua_pushinteger(L, ctx->transport.bar);
    return 1;
  }
  if (strcmp(key, "tempo") == 0) {
    lua_pushnumber(L, ctx->transport.tempo);
    return 1;
  }
  if (strcmp(key, "playing") == 0) {
    lua_pushboolean(L, ctx->transport.playing);
    return 1;
  }
  if (strcmp(key, "sample_rate") == 0) {
    lua_pushnumber(L, ctx->transport.sampleRate);
    return 1;
  }
  if (strcmp(key, "time_sig_num") == 0) {
    lua_pushinteger(L, ctx->transport.timeSigNum);
    return 1;
  }
  if (strcmp(key, "time_sig_den") == 0) {
    lua_pushinteger(L, ctx->transport.timeSigDen);
    return 1;
  }

  // Fall through to the function table
  lua_getmetatable(L, 1);
  lua_getfield(L, -1, "__functions");
  lua_getfield(L, -1, key);
  return 1;
}

void registerPluginAPI(lua_State* L, PluginContext* ctx) {
  // Store context pointer in registry
  lua_pushlightuserdata(L, ctx);
  lua_setfield(L, LUA_REGISTRYINDEX, kContextRegistryKey);

  // Create the ctx table
  lua_newtable(L);
  int ctxTable = lua_gettop(L);

  // Create metatable with __index for read-only fields
  lua_newtable(L);
  int metaTable = lua_gettop(L);

  lua_pushcfunction(L, ctx_index);
  lua_setfield(L, metaTable, "__index");

  // Store functions in a sub-table accessible via __index
  lua_newtable(L);
  static const luaL_Reg ctxFunctions[] = {{"note_on", ctx_note_on},
                                          {"note_off", ctx_note_off},
                                          {"note", ctx_note},
                                          {"cc", ctx_cc},
                                          {"pitch_bend", ctx_pitch_bend},
                                          {"log", ctx_log},
                                          {nullptr, nullptr}};
  luaL_setfuncs(L, ctxFunctions, 0);
  lua_setfield(L, metaTable, "__functions");

  lua_setmetatable(L, ctxTable);

  // Set as global "ctx"
  lua_setglobal(L, "ctx");
}

void updateContextFields(lua_State* L, const PluginContext* ctx) {
  // Context fields are read dynamically via __index, so nothing to update here.
  // The ctx pointer in the registry already points to the live PluginContext.
  (void)L;
  (void)ctx;
}

}  // namespace FLLua
