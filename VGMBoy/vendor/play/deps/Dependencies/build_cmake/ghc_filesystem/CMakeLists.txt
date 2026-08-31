project(ghcfilesystem)

add_library(ghc_filesystem INTERFACE)
target_include_directories(ghc_filesystem INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../ghc_filesystem/include>)
target_compile_options(ghc_filesystem INTERFACE "$<$<C_COMPILER_ID:MSVC>:/utf-8>")
target_compile_options(ghc_filesystem INTERFACE "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
