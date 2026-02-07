#pragma once

#include "pluginterfaces/base/funknown.h"
#include "pluginterfaces/vst/vsttypes.h"

namespace FLLua {

// Generated UUIDs for plugin components
static const Steinberg::FUID kProcessorUID(0x1A2B3C4D, 0x5E6F7081, 0x92A3B4C5,
                                           0xD6E7F801);
static const Steinberg::FUID kControllerUID(0x2B3C4D5E, 0x6F708192, 0xA3B4C5D6,
                                            0xE7F80112);

#define FLLuaVST3Category "Instrument"

}  // namespace FLLua
