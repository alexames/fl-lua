#pragma once

#include <cstdint>
#include <variant>

namespace FLLua {

struct NoteOn {
  uint8_t note = 60;
  uint8_t velocity = 100;
  uint8_t channel = 0;
  int32_t sampleOffset = 0;
};

struct NoteOff {
  uint8_t note = 60;
  uint8_t channel = 0;
  int32_t sampleOffset = 0;
};

struct CC {
  uint8_t controller = 0;
  uint8_t value = 0;
  uint8_t channel = 0;
  int32_t sampleOffset = 0;
};

struct PitchBend {
  int16_t value = 0;
  uint8_t channel = 0;
  int32_t sampleOffset = 0;
};

using MidiEvent = std::variant<NoteOn, NoteOff, CC, PitchBend>;

// Scheduled note-off (for ctx.note with duration)
struct ScheduledNoteOff {
  uint8_t note;
  uint8_t channel;
  double endBeat;
};

}  // namespace FLLua
