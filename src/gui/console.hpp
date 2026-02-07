#pragma once

#include <imgui.h>

#include <string>
#include <vector>

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

}  // namespace FLLua
