#include "plugview.hpp"
#include "controller.hpp"

#include <imgui.h>
#include <imgui_impl_win32.h>
#include <imgui_impl_dx11.h>

// Forward declare message handler from imgui_impl_win32.cpp
extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

namespace FLLua {

static const wchar_t* kWindowClassName = L"FLLuaEditorWindow";

FLLuaPlugView::FLLuaPlugView(FLLuaController* controller)
    : CPluginView(nullptr)
    , m_controller(controller) {
    rect.right = kDefaultWidth;
    rect.bottom = kDefaultHeight;
}

FLLuaPlugView::~FLLuaPlugView() {
    removed();
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::isPlatformTypeSupported(Steinberg::FIDString type) {
    if (strcmp(type, Steinberg::kPlatformTypeHWND) == 0)
        return Steinberg::kResultOk;
    return Steinberg::kResultFalse;
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::attached(void* parent, Steinberg::FIDString type) {
    if (strcmp(type, Steinberg::kPlatformTypeHWND) != 0)
        return Steinberg::kResultFalse;

    auto parentHwnd = static_cast<HWND>(parent);

    // Register window class
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = wndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kWindowClassName;
    RegisterClassExW(&wc);

    // Create child window
    m_hwnd = CreateWindowExW(
        0, kWindowClassName, L"FL-Lua",
        WS_CHILD | WS_VISIBLE,
        0, 0, kDefaultWidth, kDefaultHeight,
        parentHwnd, nullptr, wc.hInstance, this
    );

    if (!m_hwnd) return Steinberg::kResultFalse;

    // Initialize DX11
    if (!m_dx11.init(m_hwnd, kDefaultWidth, kDefaultHeight)) {
        DestroyWindow(m_hwnd);
        m_hwnd = nullptr;
        return Steinberg::kResultFalse;
    }

    // Initialize ImGui
    initImGui();

    // Initialize editor UI
    m_editor.init();

    // Set up callbacks
    m_editor.setRunCallback([this](const std::string& source) {
        if (m_controller) {
            m_controller->sendScript(source);
        }
    });

    m_editor.setStopCallback([this]() {
        if (m_controller) {
            // Send empty script to stop
            m_controller->sendScript("");
        }
    });

    // Start render timer (60 fps)
    m_timerId = SetTimer(m_hwnd, 1, 16, nullptr);

    return CPluginView::attached(parent, type);
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::removed() {
    if (m_timerId) {
        KillTimer(m_hwnd, m_timerId);
        m_timerId = 0;
    }

    shutdownImGui();
    m_dx11.shutdown();

    if (m_hwnd) {
        DestroyWindow(m_hwnd);
        m_hwnd = nullptr;
    }

    UnregisterClassW(kWindowClassName, GetModuleHandleW(nullptr));

    return CPluginView::removed();
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::getSize(Steinberg::ViewRect* size) {
    if (!size) return Steinberg::kInvalidArgument;
    *size = rect;
    return Steinberg::kResultOk;
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::onSize(Steinberg::ViewRect* newSize) {
    if (!newSize) return Steinberg::kInvalidArgument;
    rect = *newSize;

    int w = rect.right - rect.left;
    int h = rect.bottom - rect.top;

    if (m_hwnd) {
        SetWindowPos(m_hwnd, nullptr, 0, 0, w, h, SWP_NOMOVE | SWP_NOZORDER);
        m_dx11.resize(w, h);
    }

    return CPluginView::onSize(newSize);
}

Steinberg::tresult PLUGIN_API FLLuaPlugView::canResize() {
    return Steinberg::kResultTrue;
}

LRESULT CALLBACK FLLuaPlugView::wndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (ImGui_ImplWin32_WndProcHandler(hwnd, msg, wParam, lParam))
        return true;

    auto* view = reinterpret_cast<FLLuaPlugView*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_CREATE: {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
            return 0;
        }
        case WM_TIMER:
            if (view) view->renderFrame();
            return 0;
        case WM_SIZE:
            if (view && view->m_dx11.getDevice()) {
                view->m_dx11.resize(LOWORD(lParam), HIWORD(lParam));
            }
            return 0;
        case WM_DESTROY:
            return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void FLLuaPlugView::renderFrame() {
    if (!m_imguiInitialized) return;

    // Begin ImGui frame
    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    ImGui::NewFrame();

    // Render the editor as a fullscreen window
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    RECT clientRect;
    GetClientRect(m_hwnd, &clientRect);
    ImGui::SetNextWindowSize(ImVec2(
        static_cast<float>(clientRect.right),
        static_cast<float>(clientRect.bottom)
    ));

    ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                             ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoCollapse |
                             ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoBringToFrontOnFocus;

    ImGui::Begin("FL-Lua Editor", nullptr, flags);
    m_editor.render();
    ImGui::End();

    // Render
    ImGui::Render();
    m_dx11.beginFrame();
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
    m_dx11.endFrame();
}

void FLLuaPlugView::initImGui() {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    // Dark theme
    ImGui::StyleColorsDark();
    auto& style = ImGui::GetStyle();
    style.WindowRounding = 0.0f;
    style.FrameRounding = 2.0f;
    style.ScrollbarRounding = 2.0f;

    ImGui_ImplWin32_Init(m_hwnd);
    ImGui_ImplDX11_Init(m_dx11.getDevice(), m_dx11.getDeviceContext());

    m_imguiInitialized = true;
}

void FLLuaPlugView::shutdownImGui() {
    if (!m_imguiInitialized) return;

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();

    m_imguiInitialized = false;
}

} // namespace FLLua
