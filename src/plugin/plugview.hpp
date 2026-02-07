#pragma once

#include <Windows.h>

#include "gui/dx11_context.hpp"
#include "gui/editor.hpp"
#include "public.sdk/source/common/pluginview.h"

namespace FLLua {

class FLLuaController;

class FLLuaPlugView : public Steinberg::CPluginView {
 public:
  explicit FLLuaPlugView(FLLuaController* controller);
  ~FLLuaPlugView() override;

  // IPlugView
  Steinberg::tresult PLUGIN_API
  isPlatformTypeSupported(Steinberg::FIDString type) override;
  Steinberg::tresult PLUGIN_API attached(void* parent,
                                         Steinberg::FIDString type) override;
  Steinberg::tresult PLUGIN_API removed() override;
  Steinberg::tresult PLUGIN_API getSize(Steinberg::ViewRect* size) override;
  Steinberg::tresult PLUGIN_API onSize(Steinberg::ViewRect* newSize) override;
  Steinberg::tresult PLUGIN_API canResize() override;

 private:
  static LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                  LPARAM lParam);
  void renderFrame();
  void initImGui();
  void shutdownImGui();

  FLLuaController* m_controller = nullptr;
  HWND m_hwnd = nullptr;
  DX11Context m_dx11;
  Editor m_editor;
  bool m_imguiInitialized = false;
  UINT_PTR m_timerId = 0;

  static constexpr int kDefaultWidth = 900;
  static constexpr int kDefaultHeight = 650;
};

}  // namespace FLLua
