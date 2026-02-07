#include "processor.hpp"
#include "controller.hpp"
#include "cids.hpp"
#include "version.hpp"

#include "public.sdk/source/main/pluginfactory.h"

#define stringPluginName "FL-Lua"

using namespace Steinberg::Vst;
using namespace FLLua;

BEGIN_FACTORY_DEF(stringCompanyName,
                  "https://github.com/alexames/fl-lua",
                  "mailto:dev@fl-lua.local")

    DEF_CLASS2(INLINE_UID_FROM_FUID(kProcessorUID),
               PClassInfo::kManyInstances,
               kVstAudioEffectClass,
               stringPluginName,
               Vst::kDistributable,
               FLLuaVST3Category,
               FULL_VERSION_STR,
               kVstVersionString,
               FLLuaProcessor::createInstance)

    DEF_CLASS2(INLINE_UID_FROM_FUID(kControllerUID),
               PClassInfo::kManyInstances,
               kVstComponentControllerClass,
               stringPluginName "Controller",
               0,
               "",
               FULL_VERSION_STR,
               kVstVersionString,
               FLLuaController::createInstance)

END_FACTORY
