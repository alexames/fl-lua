#include "engine.hpp"

#include <fmt/format.h>

#include "sandbox.hpp"

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

namespace FLLua {

LuaEngine::LuaEngine() = default;

LuaEngine::~LuaEngine() { shutdown(); }

bool LuaEngine::init(PluginContext* ctx, const std::string& luaLibsPath) {
  shutdown();
  m_ctx = ctx;

  m_L = luaL_newstate();
  if (!m_L) return false;

  // Open sandboxed standard libraries
  openSandboxedLibs(m_L);

  // Configure package.path for bundled Lua libraries
  if (!luaLibsPath.empty()) {
    configurePackagePath(m_L, luaLibsPath);
  }

  // Register the plugin API (ctx table)
  registerPluginAPI(m_L, ctx);

  // Set instruction count hook to prevent infinite loops (10M instructions)
  lua_sethook(
      m_L,
      [](lua_State* L, lua_Debug*) {
        luaL_error(L,
                   "Script exceeded maximum instruction count (possible "
                   "infinite loop)");
      },
      LUA_MASKCOUNT, 10000000);

  return true;
}

std::string LuaEngine::loadScript(const std::string& source) {
  if (!m_L) return "Lua engine not initialized";

  m_scriptLoaded = false;

  // Compile the script
  int result = luaL_loadstring(m_L, source.c_str());
  if (result != LUA_OK) {
    std::string error = lua_tostring(m_L, -1);
    lua_pop(m_L, 1);
    return error;
  }

  // Execute the script (this defines the global functions like on_beat,
  // process)
  result = lua_pcall(m_L, 0, 0, 0);
  if (result != LUA_OK) {
    std::string error = lua_tostring(m_L, -1);
    lua_pop(m_L, 1);
    return error;
  }

  m_scriptLoaded = true;
  return {};
}

std::string LuaEngine::callOnBeat(int beatNumber) {
  if (!m_L || !m_scriptLoaded) return {};

  lua_getglobal(m_L, "on_beat");
  if (!lua_isfunction(m_L, -1)) {
    lua_pop(m_L, 1);
    return {};  // on_beat not defined, that's fine
  }

  // Push ctx table
  lua_getglobal(m_L, "ctx");
  lua_pushinteger(m_L, beatNumber);

  int result = lua_pcall(m_L, 2, 0, 0);
  if (result != LUA_OK) {
    std::string error = lua_tostring(m_L, -1);
    lua_pop(m_L, 1);
    return error;
  }
  return {};
}

std::string LuaEngine::callProcess() {
  if (!m_L || !m_scriptLoaded) return {};

  lua_getglobal(m_L, "process");
  if (!lua_isfunction(m_L, -1)) {
    lua_pop(m_L, 1);
    return {};  // process not defined, that's fine
  }

  // Push ctx table
  lua_getglobal(m_L, "ctx");

  int result = lua_pcall(m_L, 1, 0, 0);
  if (result != LUA_OK) {
    std::string error = lua_tostring(m_L, -1);
    lua_pop(m_L, 1);
    return error;
  }
  return {};
}

void LuaEngine::shutdown() {
  if (m_L) {
    lua_close(m_L);
    m_L = nullptr;
  }
  m_scriptLoaded = false;
}

}  // namespace FLLua
