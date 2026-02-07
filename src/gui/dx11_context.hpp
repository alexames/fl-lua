#pragma once

#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>

namespace FLLua {

class DX11Context {
public:
    bool init(HWND hwnd, int width, int height);
    void shutdown();
    void resize(int width, int height);
    void beginFrame();
    void endFrame();

    ID3D11Device* getDevice() const { return m_device.Get(); }
    ID3D11DeviceContext* getDeviceContext() const { return m_deviceContext.Get(); }

private:
    void createRenderTarget();
    void cleanupRenderTarget();

    Microsoft::WRL::ComPtr<ID3D11Device> m_device;
    Microsoft::WRL::ComPtr<ID3D11DeviceContext> m_deviceContext;
    Microsoft::WRL::ComPtr<IDXGISwapChain> m_swapChain;
    Microsoft::WRL::ComPtr<ID3D11RenderTargetView> m_renderTargetView;
};

} // namespace FLLua
