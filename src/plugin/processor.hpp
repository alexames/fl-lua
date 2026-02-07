#pragma once

#include "public.sdk/source/vst/vstaudioeffect.h"
#include "events/event_queue.hpp"
#include "events/midi_event.hpp"
#include "transport/transport.hpp"
#include "lua/engine.hpp"
#include "lua/api.hpp"
#include <vector>
#include <memory>

namespace FLLua {

class FLLuaProcessor : public Steinberg::Vst::AudioEffect {
public:
    FLLuaProcessor();
    ~FLLuaProcessor() override;

    static Steinberg::FUnknown* createInstance(void*) {
        return (Steinberg::Vst::IAudioProcessor*)new FLLuaProcessor;
    }

    Steinberg::tresult PLUGIN_API initialize(Steinberg::FUnknown* context) override;
    Steinberg::tresult PLUGIN_API terminate() override;
    Steinberg::tresult PLUGIN_API setActive(Steinberg::TBool state) override;
    Steinberg::tresult PLUGIN_API canProcessSampleSize(Steinberg::int32 symbolicSampleSize) override;
    Steinberg::tresult PLUGIN_API process(Steinberg::Vst::ProcessData& data) override;
    Steinberg::tresult PLUGIN_API setState(Steinberg::IBStream* state) override;
    Steinberg::tresult PLUGIN_API getState(Steinberg::IBStream* state) override;
    Steinberg::tresult PLUGIN_API notify(Steinberg::Vst::IMessage* message) override;

    // Queues shared with the controller
    MidiEventQueue& getMidiEventQueue() { return m_midiEventQueue; }
    LogQueue& getLogQueue() { return m_logQueue; }
    ScriptQueue& getScriptQueue() { return m_scriptQueue; }

private:
    void updateTransport(Steinberg::Vst::ProcessData& data);
    void processScheduledNoteOffs();
    void drainMidiEvents(Steinberg::Vst::IEventList* outputEvents);
    void sendAllNotesOff();

    LuaEngine m_luaEngine;
    PluginContext m_pluginContext;
    TransportState m_transport;
    MidiEventQueue m_midiEventQueue;
    LogQueue m_logQueue;
    ScriptQueue m_scriptQueue;
    std::vector<ScheduledNoteOff> m_scheduledNoteOffs;
    std::string m_currentScriptSource;
    std::string m_luaLibsPath;
};

} // namespace FLLua
