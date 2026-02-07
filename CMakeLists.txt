cmake_minimum_required(VERSION 3.21)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(vcpkg_bootstrap)

project(FL-Lua
  VERSION 0.1.0
  DESCRIPTION "VST3 Lua scripting plugin for FL Studio"
  LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
  add_compile_options(/utf-8)
endif()

# --- VST3 SDK (source-distribution port via vcpkg) ---
find_package(vst3sdk CONFIG REQUIRED)
set(SMTG_ENABLE_VST3_HOSTING_EXAMPLES OFF)
set(SMTG_ENABLE_VST3_PLUGIN_EXAMPLES OFF)
set(SMTG_ENABLE_VSTGUI_SUPPORT OFF)
set(SMTG_CREATE_BUNDLE_FOR_WINDOWS ON)
set(SMTG_RUN_VST_VALIDATOR OFF)
set(SMTG_CREATE_PLUGIN_LINK OFF)

add_subdirectory(${vst3sdk_SOURCE_DIR} ${PROJECT_BINARY_DIR}/vst3sdk)
smtg_enable_vst3_sdk()

# --- vcpkg dependencies ---
find_package(lua55 CONFIG REQUIRED)
find_package(luawrapper REQUIRED)
find_package(imgui CONFIG REQUIRED)
find_package(imgui-color-text-edit CONFIG REQUIRED)
find_package(readerwriterqueue CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)

# --- Plugin sources ---
set(FL_LUA_SOURCES
  src/plugin/cids.hpp
  src/plugin/version.hpp
  src/plugin/entry.cpp
  src/plugin/processor.hpp
  src/plugin/processor.cpp
  src/plugin/controller.hpp
  src/plugin/controller.cpp
  src/plugin/plugview.hpp
  src/plugin/plugview.cpp
  src/gui/dx11_context.hpp
  src/gui/dx11_context.cpp
  src/gui/editor.hpp
  src/gui/editor.cpp
  src/gui/console.hpp
  src/gui/console.cpp
  src/lua/engine.hpp
  src/lua/engine.cpp
  src/lua/api.hpp
  src/lua/api.cpp
  src/lua/sandbox.hpp
  src/lua/sandbox.cpp
  src/transport/transport.hpp
  src/events/midi_event.hpp
  src/events/event_queue.hpp
)

smtg_add_vst3plugin(FL-Lua ${FL_LUA_SOURCES})

target_include_directories(FL-Lua PRIVATE src)

target_compile_features(FL-Lua PUBLIC cxx_std_23)

target_link_libraries(FL-Lua PRIVATE
  sdk
  imgui::imgui
  imgui-color-text-edit::ImGuiColorTextEdit
  lua55::lua55
  luawrapper::luawrapper
  readerwriterqueue::readerwriterqueue
  fmt::fmt
  spdlog::spdlog
  d3d11
  dxgi
)

# --- Copy lua_libs into the VST3 bundle Resources ---
add_custom_command(TARGET FL-Lua POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E rm -rf "$<TARGET_FILE_DIR:FL-Lua>/../Resources/lua_libs"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/lua_libs"
    "$<TARGET_FILE_DIR:FL-Lua>/../Resources/lua_libs"
  COMMENT "Copying Lua libraries to plugin bundle"
)

# --- Install the .vst3 bundle ---
install(CODE "
  file(INSTALL \"${CMAKE_BINARY_DIR}/VST3/\${CMAKE_INSTALL_CONFIG_NAME}/FL-Lua.vst3/\"
    DESTINATION \"\${CMAKE_INSTALL_PREFIX}/FL-Lua.vst3\")
")
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/scripts/examples/"
  DESTINATION "examples"
)
