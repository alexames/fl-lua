#include "dx11_context.hpp"

namespace FLLua {

bool DX11Context::init(HWND hwnd, int width, int height) {
    DXGI_SWAP_CHAIN_DESC sd = {};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = static_cast<UINT>(width);
    sd.BufferDesc.Height = static_cast<UINT>(height);
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    UINT createDeviceFlags = 0;
    D3D_FEATURE_LEVEL featureLevel;
    const D3D_FEATURE_LEVEL featureLevelArray[2] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_0,
    };

    HRESULT hr = D3D11CreateDeviceAndSwapChain(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        createDeviceFlags, featureLevelArray, 2,
        D3D11_SDK_VERSION, &sd,
        m_swapChain.GetAddressOf(),
        m_device.GetAddressOf(),
        &featureLevel,
        m_deviceContext.GetAddressOf()
    );

    if (FAILED(hr)) return false;

    createRenderTarget();
    return true;
}

void DX11Context::shutdown() {
    cleanupRenderTarget();
    m_swapChain.Reset();
    m_deviceContext.Reset();
    m_device.Reset();
}

void DX11Context::resize(int width, int height) {
    if (!m_swapChain) return;
    cleanupRenderTarget();
    m_swapChain->ResizeBuffers(0, static_cast<UINT>(width), static_cast<UINT>(height),
                                DXGI_FORMAT_UNKNOWN, 0);
    createRenderTarget();
}

void DX11Context::beginFrame() {
    float clearColor[4] = {0.1f, 0.1f, 0.12f, 1.0f};
    m_deviceContext->OMSetRenderTargets(1, m_renderTargetView.GetAddressOf(), nullptr);
    m_deviceContext->ClearRenderTargetView(m_renderTargetView.Get(), clearColor);
}

void DX11Context::endFrame() {
    m_swapChain->Present(1, 0); // VSync
}

void DX11Context::createRenderTarget() {
    Microsoft::WRL::ComPtr<ID3D11Texture2D> backBuffer;
    m_swapChain->GetBuffer(0, IID_PPV_ARGS(backBuffer.GetAddressOf()));
    if (backBuffer) {
        m_device->CreateRenderTargetView(backBuffer.Get(), nullptr,
                                          m_renderTargetView.GetAddressOf());
    }
}

void DX11Context::cleanupRenderTarget() {
    m_renderTargetView.Reset();
}

} // namespace FLLua
