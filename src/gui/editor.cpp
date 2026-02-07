#include "editor.hpp"

#include <Windows.h>
#include <commdlg.h>
#include <imgui.h>

#include <fstream>
#include <sstream>

namespace FLLua {

void Editor::init() {
  // Configure the text editor for Lua
  auto lang = TextEditor::LanguageDefinition::Lua();
  m_textEditor.SetLanguageDefinition(lang);
  m_textEditor.SetShowWhitespaces(false);
  m_textEditor.SetTabSize(2);

  // Default script
  m_textEditor.SetText(R"(-- FL-Lua Script
-- Available callbacks: on_beat(ctx, beat), process(ctx)
-- Available functions: ctx.note(pitch, vel, duration)
--                      ctx.note_on(pitch, vel), ctx.note_off(pitch)
--                      ctx.cc(controller, value), ctx.log(message)
-- Available fields:    ctx.beat, ctx.bar, ctx.tempo, ctx.playing

function on_beat(ctx, beat)
    ctx.note(60, 100, 0.5)  -- Play middle C, velocity 100, half beat
    ctx.log("Beat: " .. beat)
end
)");
}

void Editor::render() {
  renderMenuBar();

  // Main area: code editor takes most space, console at bottom
  ImVec2 avail = ImGui::GetContentRegionAvail();
  float editorHeight =
      avail.y - m_consolePanelHeight - ImGui::GetFrameHeightWithSpacing() - 4;

  if (editorHeight < 100) editorHeight = 100;

  renderCodeEditor();

  // Splitter
  ImGui::Separator();

  // Console panel
  ImGui::BeginChild("ConsolePanel", ImVec2(0, m_consolePanelHeight));
  ImGui::Text("Console");
  ImGui::SameLine();
  if (ImGui::SmallButton("Clear")) {
    m_console.clear();
  }
  ImGui::Separator();
  m_console.render();
  ImGui::EndChild();

  renderStatusBar();
}

void Editor::renderMenuBar() {
  if (ImGui::BeginMenuBar()) {
    if (ImGui::BeginMenu("File")) {
      if (ImGui::MenuItem("Open...", "Ctrl+O")) openFile();
      if (ImGui::MenuItem("Save", "Ctrl+S")) saveFile();
      ImGui::EndMenu();
    }
    if (ImGui::BeginMenu("Script")) {
      if (ImGui::MenuItem("Run", "Ctrl+Enter", false, !m_running)) runScript();
      if (ImGui::MenuItem("Stop", nullptr, false, m_running)) stopScript();
      ImGui::EndMenu();
    }
    ImGui::EndMenuBar();
  }

  // Keyboard shortcuts
  auto& io = ImGui::GetIO();
  if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_Enter)) runScript();
  if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_O)) openFile();
  if (io.KeyCtrl && ImGui::IsKeyPressed(ImGuiKey_S)) saveFile();
}

void Editor::renderCodeEditor() { m_textEditor.Render("CodeEditor"); }

void Editor::renderConsolePanel() { m_console.render(); }

void Editor::renderStatusBar() {
  auto cpos = m_textEditor.GetCursorPosition();
  ImGui::Text(
      "Ln %d, Col %d | %s | %s", cpos.mLine + 1, cpos.mColumn + 1,
      m_running ? "Running" : "Stopped",
      m_currentFilePath.empty() ? "Untitled" : m_currentFilePath.c_str());
}

void Editor::setScriptText(const std::string& text) {
  m_textEditor.SetText(text);
}

std::string Editor::getScriptText() const { return m_textEditor.GetText(); }

void Editor::openFile() {
  char filename[MAX_PATH] = {};
  OPENFILENAMEA ofn = {};
  ofn.lStructSize = sizeof(ofn);
  ofn.lpstrFilter = "Lua Scripts (*.lua)\0*.lua\0All Files (*.*)\0*.*\0";
  ofn.lpstrFile = filename;
  ofn.nMaxFile = MAX_PATH;
  ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
  ofn.lpstrDefExt = "lua";

  if (GetOpenFileNameA(&ofn)) {
    std::ifstream file(filename);
    if (file.is_open()) {
      std::stringstream ss;
      ss << file.rdbuf();
      m_textEditor.SetText(ss.str());
      m_currentFilePath = filename;
      m_console.addMessage("Opened: " + m_currentFilePath);
    }
  }
}

void Editor::saveFile() {
  if (m_currentFilePath.empty()) {
    char filename[MAX_PATH] = {};
    OPENFILENAMEA ofn = {};
    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = "Lua Scripts (*.lua)\0*.lua\0All Files (*.*)\0*.*\0";
    ofn.lpstrFile = filename;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_OVERWRITEPROMPT;
    ofn.lpstrDefExt = "lua";

    if (!GetSaveFileNameA(&ofn)) return;
    m_currentFilePath = filename;
  }

  std::ofstream file(m_currentFilePath);
  if (file.is_open()) {
    file << m_textEditor.GetText();
    m_console.addMessage("Saved: " + m_currentFilePath);
  }
}

void Editor::runScript() {
  m_running = true;
  if (m_runCallback) {
    m_runCallback(m_textEditor.GetText());
  }
}

void Editor::stopScript() {
  m_running = false;
  if (m_stopCallback) {
    m_stopCallback();
  }
}

}  // namespace FLLua
