#include "console.hpp"

namespace FLLua {

void Console::addMessage(const std::string& msg) {
  m_messages.push_back(msg);
  if (m_messages.size() > kMaxMessages) {
    m_messages.erase(m_messages.begin());
  }
  m_scrollToBottom = true;
}

void Console::clear() { m_messages.clear(); }

void Console::render() {
  ImGui::BeginChild("ConsoleOutput", ImVec2(0, 0), ImGuiChildFlags_None,
                    ImGuiWindowFlags_HorizontalScrollbar);

  for (const auto& msg : m_messages) {
    // Color errors red
    if (msg.find("error") != std::string::npos ||
        msg.find("Error") != std::string::npos) {
      ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.3f, 0.3f, 1.0f));
      ImGui::TextUnformatted(msg.c_str());
      ImGui::PopStyleColor();
    } else {
      ImGui::TextUnformatted(msg.c_str());
    }
  }

  if (m_scrollToBottom) {
    ImGui::SetScrollHereY(1.0f);
    m_scrollToBottom = false;
  }

  ImGui::EndChild();
}

}  // namespace FLLua
