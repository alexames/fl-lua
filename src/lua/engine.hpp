#pragma once

#include "api.hpp"
#include <string>
#include <functional>

struct lua_State;

namespace FLLua {

class LuaEngine {
public:
    LuaEngine();
    ~LuaEngine();

    // Initialize the Lua state with sandboxed libs and plugin API
    bool init(PluginContext* ctx, const std::string& luaLibsPath);

    // Load and execute a script. Returns error message on failure, empty on success.
    std::string loadScript(const std::string& source);

    // Call on_beat(ctx, beat_number) if defined
    std::string callOnBeat(int beatNumber);

    // Call process(ctx) if defined
    std::string callProcess();

    // Shutdown the Lua state
    void shutdown();

    bool isInitialized() const { return m_L != nullptr; }
    bool hasScript() const { return m_scriptLoaded; }

private:
    lua_State* m_L = nullptr;
    bool m_scriptLoaded = false;
    PluginContext* m_ctx = nullptr;

    // Call a global function safely, returns error or empty
    std::string callGlobalFunction(const char* name, int nargs = 0);
};

} // namespace FLLua
