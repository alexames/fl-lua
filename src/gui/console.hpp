#pragma once

#include <string>
#include <vector>
#include <imgui.h>

namespace FLLua {

class Console {
public:
    void addMessage(const std::string& msg);
    void clear();
    void render();

private:
    std::vector<std::string> m_messages;
    bool m_scrollToBottom = false;
    static constexpr size_t kMaxMessages = 500;
};

} // namespace FLLua
