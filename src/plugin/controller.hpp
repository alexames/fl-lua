#pragma once

#include <mutex>
#include <string>
#include <vector>

#include "public.sdk/source/vst/vsteditcontroller.h"

namespace FLLua {

class FLLuaController : public Steinberg::Vst::EditController {
 public:
  static Steinberg::FUnknown* createInstance(void*) {
    return (Steinberg::Vst::IEditController*)new FLLuaController;
  }

  Steinberg::tresult PLUGIN_API
  initialize(Steinberg::FUnknown* context) override;
  Steinberg::tresult PLUGIN_API terminate() override;
  Steinberg::IPlugView* PLUGIN_API
  createView(Steinberg::FIDString name) override;
  Steinberg::tresult PLUGIN_API
  setComponentState(Steinberg::IBStream* state) override;
  Steinberg::tresult PLUGIN_API
  notify(Steinberg::Vst::IMessage* message) override;

  // Send a script source to the processor
  void sendScript(const std::string& source);

  // Send lua_libs path to the processor
  void sendLuaLibsPath(const std::string& path);

  // Drain pending log messages (called from UI thread)
  std::vector<std::string> drainLogMessages();

 private:
  std::mutex m_logMutex;
  std::vector<std::string> m_pendingLogs;
};

}  // namespace FLLua
