cmake_minimum_required(VERSION 3.24)
project(garrycraft LANGUAGES CXX)
if(WIN32)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
elseif(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
  message(FATAL_ERROR "GarryCraft requires 64-bit Windows or 64-bit Linux")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "GarryCraft requires a 64-bit target")
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(GARRYCRAFT_SUFFIX "linux64")
  # GNUC selects the SDK's GCC branches (visibility, alignment, builtins).
  set(GARRYCRAFT_PLATFORM_DEFINES LINUX _LINUX POSIX GNUC COMPILER_GCC)
else()
  set(GARRYCRAFT_SUFFIX "win64")
  set(GARRYCRAFT_PLATFORM_DEFINES _WIN32 _WINDOWS COMPILER_MSVC COMPILER_MSVC64)
endif()
include(FetchContent)
FetchContent_Declare(gmod_sdk
  GIT_REPOSITORY https://github.com/danielga/garrysmod_common.git
  GIT_TAG f77a18d86f780a59ea30e4237016b05b790d4b70)
FetchContent_MakeAvailable(gmod_sdk)
foreach(realm IN ITEMS gmsv gmcl)
  add_library(${realm}_garrycraft MODULE src/module.cpp src/mailbox.cpp)
  target_include_directories(${realm}_garrycraft PRIVATE ${gmod_sdk_SOURCE_DIR}/include)
  target_compile_features(${realm}_garrycraft PRIVATE cxx_std_20)
  target_compile_definitions(${realm}_garrycraft PRIVATE GMMODULE WIN32_LEAN_AND_MEAN NOMINMAX ${GARRYCRAFT_PLATFORM_DEFINES})
  set_target_properties(${realm}_garrycraft PROPERTIES PREFIX "" OUTPUT_NAME "${realm}_garrycraft_${GARRYCRAFT_SUFFIX}")
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # GMod loads Linux modules from files named *.dll that contain ELF objects.
    set_target_properties(${realm}_garrycraft PROPERTIES SUFFIX ".dll")
    target_compile_options(${realm}_garrycraft PRIVATE -fPIC -fvisibility=hidden -fvisibility-inlines-hidden -fno-math-errno)
    # Match the Windows static runtime: the game process may carry an older libstdc++.
    target_link_options(${realm}_garrycraft PRIVATE -static-libstdc++ -static-libgcc
      -Wl,--exclude-libs,ALL -Wl,--no-undefined)
  endif()
endforeach()
target_sources(gmsv_garrycraft PRIVATE src/runtime.cpp src/geometry.cpp)
target_sources(gmcl_garrycraft PRIVATE src/textures.cpp src/framerate.cpp src/meshes.cpp src/receiver.cpp src/packets.cpp src/shadows.cpp)
target_include_directories(gmcl_garrycraft PRIVATE ${gmod_sdk_SOURCE_DIR}/sourcesdk-minimal/public
    ${gmod_sdk_SOURCE_DIR}/sourcesdk-minimal/public/tier0 ${gmod_sdk_SOURCE_DIR}/sourcesdk-minimal/public/tier1)
# The Linux client avoids GMOD_USE_SOURCESDK: the pinned SDK's mathlib headers
# are not LP64-clean (CInterlockedIntT assumes 4-byte long). Meshes use GMod's
# public mesh calls, textures use vendored pure-virtual declarations, and the
# Lua Vector layout (three floats) is ABI-identical for bridge purposes.
if(WIN32)
  target_compile_definitions(gmcl_garrycraft PRIVATE GARRYCRAFT_CLIENT GMOD_USE_SOURCESDK _WIN32 _WINDOWS COMPILER_MSVC COMPILER_MSVC64)
else()
  target_compile_definitions(gmcl_garrycraft PRIVATE GARRYCRAFT_CLIENT LINUX _LINUX POSIX GNUC COMPILER_GCC)
endif()

# Build explicitly for renderer compatibility E2E tests. Release packaging copies only the two bridge modules.
add_library(garrycraft_shadow_test MODULE EXCLUDE_FROM_ALL ../tests/shadow-hooks.cpp)
get_target_property(shadow_test_includes gmcl_garrycraft INCLUDE_DIRECTORIES)
target_include_directories(garrycraft_shadow_test PRIVATE ${shadow_test_includes})
target_compile_features(garrycraft_shadow_test PRIVATE cxx_std_20)
if(WIN32)
  target_compile_definitions(garrycraft_shadow_test PRIVATE GMMODULE WIN32_LEAN_AND_MEAN NOMINMAX GMOD_USE_SOURCESDK _WIN32 _WINDOWS COMPILER_MSVC COMPILER_MSVC64)
else()
  target_compile_definitions(garrycraft_shadow_test PRIVATE GMMODULE GMOD_USE_SOURCESDK LINUX _LINUX POSIX GNUC COMPILER_GCC)
endif()
set_target_properties(garrycraft_shadow_test PROPERTIES PREFIX "" OUTPUT_NAME "gmcl_garrycraft_shadow_test_${GARRYCRAFT_SUFFIX}")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set_target_properties(garrycraft_shadow_test PROPERTIES SUFFIX ".dll")
  target_compile_options(garrycraft_shadow_test PRIVATE -fPIC)
endif()
