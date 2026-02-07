#include "processor.hpp"

#include <algorithm>
#include <cstring>

#include "base/source/fstreamer.h"
#include "cids.hpp"
#include "pluginterfaces/base/ibstream.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/vst/ivstmidicontrollers.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"

namespace FLLua {

FLLuaProcessor::FLLuaProcessor() { setControllerClass(kControllerUID); }

FLLuaProcessor::~FLLuaProcessor() = default;

Steinberg::tresult PLUGIN_API
FLLuaProcessor::initialize(Steinberg::FUnknown* context) {
  auto result = AudioEffect::initialize(context);
  if (result != Steinberg::kResultOk) return result;

  // Add a dummy stereo audio output (required for some hosts)
  addAudioOutput(STR16("Stereo Out"), Steinberg::Vst::SpeakerArr::kStereo);

  // Add event output bus for MIDI
  addEventOutput(STR16("Event Out"), 1);

  // Determine lua_libs path relative to plugin location
  // This will be set properly when the plugin bundle path is known
  m_luaLibsPath = "";

  return Steinberg::kResultOk;
}

Steinberg::tresult PLUGIN_API FLLuaProcessor::terminate() {
  m_luaEngine.shutdown();
  return AudioEffect::terminate();
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::setActive(Steinberg::TBool state) {
  if (state) {
    // Initialize Lua engine
    m_pluginContext.eventQueue = &m_midiEventQueue;
    m_pluginContext.logQueue = &m_logQueue;
    m_pluginContext.scheduledNoteOffs = &m_scheduledNoteOffs;

    m_luaEngine.init(&m_pluginContext, m_luaLibsPath);

    // Reload script if we have one saved
    if (!m_currentScriptSource.empty()) {
      auto error = m_luaEngine.loadScript(m_currentScriptSource);
      if (!error.empty()) {
        m_logQueue.enqueue("Script error: " + error);
      }
    }
  } else {
    sendAllNotesOff();
    m_luaEngine.shutdown();
  }

  return AudioEffect::setActive(state);
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::canProcessSampleSize(Steinberg::int32 symbolicSampleSize) {
  if (symbolicSampleSize == Steinberg::Vst::kSample32)
    return Steinberg::kResultTrue;
  return Steinberg::kResultFalse;
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::process(Steinberg::Vst::ProcessData& data) {
  // Check for new script from the UI thread
  ScriptSwapMessage msg;
  while (m_scriptQueue.try_dequeue(msg)) {
    m_currentScriptSource = msg.source;
    sendAllNotesOff();
    m_scheduledNoteOffs.clear();

    // Reinitialize Lua engine with new script
    m_luaEngine.init(&m_pluginContext, m_luaLibsPath);
    auto error = m_luaEngine.loadScript(m_currentScriptSource);
    if (!error.empty()) {
      m_logQueue.enqueue("Script error: " + error);
    } else {
      m_logQueue.enqueue("Script loaded successfully.");
    }
  }

  // Update transport state
  updateTransport(data);

  // Run Lua callbacks if playing and script is loaded
  if (m_transport.playing && m_luaEngine.hasScript()) {
    // Call on_beat at beat boundaries
    if (m_transport.isBeatBoundary()) {
      auto error = m_luaEngine.callOnBeat(m_transport.currentBeatInt());
      if (!error.empty()) {
        m_logQueue.enqueue("on_beat error: " + error);
      }
    }

    // Call process every block
    auto error = m_luaEngine.callProcess();
    if (!error.empty()) {
      m_logQueue.enqueue("process error: " + error);
    }
  }

  // Update lastBeatInt for next boundary detection
  m_transport.lastBeatInt = m_transport.currentBeatInt();

  // Process scheduled note-offs
  processScheduledNoteOffs();

  // Drain MIDI events to VST3 output
  if (data.outputEvents) {
    drainMidiEvents(data.outputEvents);
  }

  // Output silence on audio bus
  if (data.numOutputs > 0 && data.outputs) {
    for (int ch = 0; ch < data.outputs[0].numChannels; ++ch) {
      if (data.outputs[0].channelBuffers32[ch]) {
        std::memset(data.outputs[0].channelBuffers32[ch], 0,
                    static_cast<size_t>(data.numSamples) * sizeof(float));
      }
    }
    data.outputs[0].silenceFlags = 0x3;  // Both channels silent
  }

  return Steinberg::kResultOk;
}

void FLLuaProcessor::updateTransport(Steinberg::Vst::ProcessData& data) {
  if (!data.processContext) return;

  auto* ctx = data.processContext;

  if (ctx->state & Steinberg::Vst::ProcessContext::kTempoValid)
    m_transport.tempo = ctx->tempo;

  if (ctx->state & Steinberg::Vst::ProcessContext::kProjectTimeMusicValid)
    m_transport.beat = ctx->projectTimeMusic;

  if (ctx->state & Steinberg::Vst::ProcessContext::kTimeSigValid) {
    m_transport.timeSigNum = ctx->timeSigNumerator;
    m_transport.timeSigDen = ctx->timeSigDenominator;
  }

  m_transport.playing =
      (ctx->state & Steinberg::Vst::ProcessContext::kPlaying) != 0;
  m_transport.sampleRate = data.processContext->sampleRate;

  if (m_transport.timeSigNum > 0) {
    m_transport.bar =
        static_cast<int>(m_transport.beat / m_transport.timeSigNum);
  }

  // Update the plugin context so Lua can read it
  m_pluginContext.transport = m_transport;
}

void FLLuaProcessor::processScheduledNoteOffs() {
  auto it = m_scheduledNoteOffs.begin();
  while (it != m_scheduledNoteOffs.end()) {
    if (m_transport.beat >= it->endBeat) {
      m_midiEventQueue.enqueue(NoteOff{it->note, it->channel, 0});
      it = m_scheduledNoteOffs.erase(it);
    } else {
      ++it;
    }
  }
}

void FLLuaProcessor::drainMidiEvents(Steinberg::Vst::IEventList* outputEvents) {
  MidiEvent midiEvent;
  while (m_midiEventQueue.try_dequeue(midiEvent)) {
    Steinberg::Vst::Event e = {};
    e.busIndex = 0;
    e.ppqPosition = m_transport.beat;

    std::visit(
        [&e](auto&& ev) {
          using T = std::decay_t<decltype(ev)>;
          if constexpr (std::is_same_v<T, NoteOn>) {
            e.type = Steinberg::Vst::Event::kNoteOnEvent;
            e.noteOn.channel = ev.channel;
            e.noteOn.pitch = ev.note;
            e.noteOn.velocity = ev.velocity / 127.0f;
            e.noteOn.noteId = ev.note;  // Simple note ID
            e.sampleOffset = ev.sampleOffset;
          } else if constexpr (std::is_same_v<T, NoteOff>) {
            e.type = Steinberg::Vst::Event::kNoteOffEvent;
            e.noteOff.channel = ev.channel;
            e.noteOff.pitch = ev.note;
            e.noteOff.velocity = 0.0f;
            e.noteOff.noteId = ev.note;
            e.sampleOffset = ev.sampleOffset;
          } else if constexpr (std::is_same_v<T, CC>) {
            e.type = Steinberg::Vst::Event::kLegacyMIDICCOutEvent;
            e.midiCCOut.channel = ev.channel;
            e.midiCCOut.controlNumber = ev.controller;
            e.midiCCOut.value = ev.value;
            e.sampleOffset = ev.sampleOffset;
          } else if constexpr (std::is_same_v<T, PitchBend>) {
            e.type = Steinberg::Vst::Event::kLegacyMIDICCOutEvent;
            e.midiCCOut.channel = ev.channel;
            e.midiCCOut.controlNumber = 129;  // Steinberg::Vst::kPitchBend
            e.midiCCOut.value = ev.value;
            e.sampleOffset = ev.sampleOffset;
          }
        },
        midiEvent);

    outputEvents->addEvent(e);
  }
}

void FLLuaProcessor::sendAllNotesOff() {
  // Send CC 123 (All Notes Off) on all 16 channels
  for (uint8_t ch = 0; ch < 16; ++ch) {
    m_midiEventQueue.enqueue(CC{123, 0, ch, 0});
  }
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::setState(Steinberg::IBStream* state) {
  if (!state) return Steinberg::kResultFalse;

  Steinberg::IBStreamer streamer(state, kLittleEndian);

  // Read script source length
  Steinberg::int32 length = 0;
  if (!streamer.readInt32(length)) return Steinberg::kResultFalse;

  if (length > 0 && length < 1024 * 1024) {  // Max 1MB script
    m_currentScriptSource.resize(static_cast<size_t>(length));
    Steinberg::int32 bytesRead = 0;
    state->read(m_currentScriptSource.data(), length, &bytesRead);
    if (bytesRead != length) return Steinberg::kResultFalse;
  } else {
    m_currentScriptSource.clear();
  }

  return Steinberg::kResultOk;
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::getState(Steinberg::IBStream* state) {
  if (!state) return Steinberg::kResultFalse;

  Steinberg::IBStreamer streamer(state, kLittleEndian);

  // Write script source
  auto length = static_cast<Steinberg::int32>(m_currentScriptSource.size());
  streamer.writeInt32(length);
  if (length > 0) {
    Steinberg::int32 bytesWritten = 0;
    state->write((void*)m_currentScriptSource.data(), length, &bytesWritten);
  }

  return Steinberg::kResultOk;
}

Steinberg::tresult PLUGIN_API
FLLuaProcessor::notify(Steinberg::Vst::IMessage* message) {
  if (!message) return Steinberg::kInvalidArgument;

  // Handle script messages from the controller
  if (strcmp(message->getMessageID(), "ScriptSource") == 0) {
    const void* data = nullptr;
    Steinberg::uint32 size = 0;
    if (message->getAttributes()->getBinary("source", data, size) ==
        Steinberg::kResultOk) {
      std::string source(static_cast<const char*>(data), size);
      m_scriptQueue.enqueue(ScriptSwapMessage{std::move(source)});
    }
    return Steinberg::kResultOk;
  }

  if (strcmp(message->getMessageID(), "LuaLibsPath") == 0) {
    const void* data = nullptr;
    Steinberg::uint32 size = 0;
    if (message->getAttributes()->getBinary("path", data, size) ==
        Steinberg::kResultOk) {
      m_luaLibsPath = std::string(static_cast<const char*>(data), size);
    }
    return Steinberg::kResultOk;
  }

  return AudioEffect::notify(message);
}

}  // namespace FLLua
