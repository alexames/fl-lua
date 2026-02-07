include(FetchContent)

set(CMAKE_TOOLCHAIN_FILE "${FETCHCONTENT_BASE_DIR}/vcpkg-src/scripts/buildsystems/vcpkg.cmake"
  CACHE STRING "Vcpkg toolchain file")

FetchContent_Declare(
  "vcpkg"
  GIT_REPOSITORY "git@github.com:microsoft/vcpkg.git"
  GIT_TAG        "75a2e14262fc23c1f03bac18e135c4866dd25b51"
)

FetchContent_MakeAvailable("vcpkg")
