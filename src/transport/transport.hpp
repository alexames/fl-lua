#pragma once

#include <cstdint>

namespace FLLua {

struct TransportState {
  double beat = 0.0;     // Current position in quarter notes
  int bar = 0;           // Current bar number (0-indexed)
  double tempo = 120.0;  // BPM
  bool playing = false;  // Transport is running
  double sampleRate = 44100.0;
  int timeSigNum = 4;    // Time signature numerator
  int timeSigDen = 4;    // Time signature denominator
  int lastBeatInt = -1;  // For detecting beat boundaries

  bool isBeatBoundary() const {
    int currentBeatInt = static_cast<int>(beat);
    return currentBeatInt != lastBeatInt && playing;
  }

  int currentBeatInt() const { return static_cast<int>(beat); }
};

}  // namespace FLLua
