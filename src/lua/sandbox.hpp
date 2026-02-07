#pragma once

#include <string>

struct lua_State;

namespace FLLua {

// Open only safe Lua standard libraries (no io, os, debug)
void openSandboxedLibs(lua_State* L);

// Configure package.path to find bundled Lua libraries
void configurePackagePath(lua_State* L, const std::string& luaLibsPath);

// Lock the global table to prevent accidental global variable creation
void lockGlobalTable(lua_State* L);

} // namespace FLLua
