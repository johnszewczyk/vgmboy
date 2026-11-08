cmake_minimum_required(VERSION 3.20)
project(spcboy_stream LANGUAGES C CXX)

if(POLICY CMP0090)
    cmake_policy(SET CMP0090 NEW)
endif()
set(CMAKE_EXPORT_PACKAGE_REGISTRY OFF)

set(BUILD_LIBAUDIO OFF CACHE BOOL "" FORCE)
set(BUILD_LIBEMU ON CACHE BOOL "" FORCE)
set(BUILD_LIBPLAYER ON CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_PLAYER OFF CACHE BOOL "" FORCE)
set(BUILD_VGM2WAV OFF CACHE BOOL "" FORCE)
set(USE_SANITIZERS OFF CACHE BOOL "" FORCE)

find_package(PkgConfig REQUIRED)
find_package(ZLIB REQUIRED)
pkg_check_modules(GME REQUIRED IMPORTED_TARGET libgme)

add_subdirectory(vendor/libvgm)

add_executable(spcboy-stream
    src/spcboy_stream.cpp
    src/libvgm_bridge.cpp
)
target_compile_features(spcboy-stream PRIVATE cxx_std_17)
target_include_directories(spcboy-stream PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/libvgm"
)
target_link_libraries(spcboy-stream PRIVATE
    vgm-player
    vgm-emu
    vgm-utils
    PkgConfig::GME
    ZLIB::ZLIB
)
set_target_properties(spcboy-stream PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
