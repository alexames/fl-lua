#include "controller.hpp"
#include "cids.hpp"
#include "plugview.hpp"
#include "base/source/fstreamer.h"
#include "pluginterfaces/base/ibstream.h"

namespace FLLua {

Steinberg::tresult PLUGIN_API FLLuaController::initialize(Steinberg::FUnknown* context) {
    auto result = EditController::initialize(context);
    if (result != Steinberg::kResultOk) return result;
    return Steinberg::kResultOk;
}

Steinberg::tresult PLUGIN_API FLLuaController::terminate() {
    return EditController::terminate();
}

Steinberg::IPlugView* PLUGIN_API FLLuaController::createView(Steinberg::FIDString name) {
    if (Steinberg::FIDStringsEqual(name, Steinberg::Vst::ViewType::kEditor)) {
        return new FLLuaPlugView(this);
    }
    return nullptr;
}

Steinberg::tresult PLUGIN_API FLLuaController::setComponentState(Steinberg::IBStream* state) {
    if (!state) return Steinberg::kResultFalse;

    // Read the script source from processor state to show in editor
    Steinberg::IBStreamer streamer(state, kLittleEndian);
    Steinberg::int32 length = 0;
    if (streamer.readInt32(length) && length > 0 && length < 1024 * 1024) {
        std::string source(static_cast<size_t>(length), '\0');
        Steinberg::int32 bytesRead = 0;
        state->read(source.data(), length, &bytesRead);
        // The plugview will pick this up when it opens
        // Store it for later - the view will read it
    }

    return Steinberg::kResultOk;
}

void FLLuaController::sendScript(const std::string& source) {
    if (auto* msg = allocateMessage()) {
        msg->setMessageID("ScriptSource");
        msg->getAttributes()->setBinary("source", source.data(),
                                        static_cast<Steinberg::uint32>(source.size()));
        sendMessage(msg);
        msg->release();
    }
}

void FLLuaController::sendLuaLibsPath(const std::string& path) {
    if (auto* msg = allocateMessage()) {
        msg->setMessageID("LuaLibsPath");
        msg->getAttributes()->setBinary("path", path.data(),
                                        static_cast<Steinberg::uint32>(path.size()));
        sendMessage(msg);
        msg->release();
    }
}

} // namespace FLLua
