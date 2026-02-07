#include "sandbox.hpp"

#include <string>

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

namespace FLLua {

void openSandboxedLibs(lua_State* L) {
  // Open only safe libraries
  static const luaL_Reg safeLibs[] = {
      {LUA_GNAME, luaopen_base},
      {LUA_COLIBNAME, luaopen_coroutine},
      {LUA_TABLIBNAME, luaopen_table},
      {LUA_STRLIBNAME, luaopen_string},
      {LUA_MATHLIBNAME, luaopen_math},
      {LUA_UTF8LIBNAME, luaopen_utf8},
      {LUA_LOADLIBNAME, luaopen_package},  // Needed for require()
      {nullptr, nullptr}};

  for (const luaL_Reg* lib = safeLibs; lib->func; lib++) {
    luaL_requiref(L, lib->name, lib->func, 1);
    lua_pop(L, 1);
  }
}

void configurePackagePath(lua_State* L, const std::string& luaLibsPath) {
  std::string path;
  path += luaLibsPath + "/?.lua;";
  path += luaLibsPath + "/?/init.lua;";
  path += luaLibsPath + "/llx/?.lua;";
  path += luaLibsPath + "/llx/?/init.lua;";
  path += luaLibsPath + "/musica/?.lua;";
  path += luaLibsPath + "/musica/?/init.lua;";
  path += luaLibsPath + "/lua-midi/?.lua;";
  path += luaLibsPath + "/lua-midi/?/init.lua;";

  lua_getglobal(L, "package");
  lua_pushstring(L, path.c_str());
  lua_setfield(L, -2, "path");

  // Clear cpath to prevent loading arbitrary native modules
  lua_pushstring(L, "");
  lua_setfield(L, -2, "cpath");

  lua_pop(L, 1);
}

void lockGlobalTable(lua_State* L) {
  // Set a __newindex metamethod on _G that warns about global writes
  luaL_dostring(L, R"(
        setmetatable(_G, {
            __newindex = function(t, k, v)
                -- Allow setting functions (script callbacks like on_beat, process)
                if type(v) == "function" then
                    rawset(t, k, v)
                else
                    rawset(t, k, v)
                    -- Could warn here in the future
                end
            end
        })
    )");
}

}  // namespace FLLua
