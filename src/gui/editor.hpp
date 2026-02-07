#pragma once

#include "console.hpp"
#include <TextEditor.h>
#include <string>
#include <functional>

namespace FLLua {

class Editor {
public:
    using RunCallback = std::function<void(const std::string& source)>;
    using StopCallback = std::function<void()>;

    void init();
    void render();

    void setRunCallback(RunCallback cb) { m_runCallback = std::move(cb); }
    void setStopCallback(StopCallback cb) { m_stopCallback = std::move(cb); }

    void setScriptText(const std::string& text);
    std::string getScriptText() const;

    Console& getConsole() { return m_console; }

    bool isScriptRunning() const { return m_running; }

private:
    void renderMenuBar();
    void renderCodeEditor();
    void renderConsolePanel();
    void renderStatusBar();

    void openFile();
    void saveFile();
    void runScript();
    void stopScript();

    TextEditor m_textEditor;
    Console m_console;
    RunCallback m_runCallback;
    StopCallback m_stopCallback;

    std::string m_currentFilePath;
    bool m_running = false;
    float m_consolePanelHeight = 150.0f;
};

} // namespace FLLua
