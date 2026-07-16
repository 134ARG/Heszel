cmake_minimum_required(VERSION 3.5.0)
project(iroh_hos)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(
    IROH_HOS_CORE_ARCHIVE
    "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/arm64-v8a/libiroh_hos_core.a"
    CACHE FILEPATH
    "Path to the Rust iroh-hos static library"
)

add_library(iroh_hos_core STATIC IMPORTED)
set_target_properties(
    iroh_hos_core
    PROPERTIES IMPORTED_LOCATION "${IROH_HOS_CORE_ARCHIVE}"
)

add_library(iroh_hos SHARED napi_init.cpp)
set(IROH_HOS_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
if(NOT EXISTS "${IROH_HOS_INCLUDE_DIR}/iroh_hos.h")
    set(IROH_HOS_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../include")
endif()
target_include_directories(iroh_hos PRIVATE "${IROH_HOS_INCLUDE_DIR}")
target_link_libraries(iroh_hos PUBLIC libace_napi.z.so iroh_hos_core)

# Rust's static archive contains many internal symbols; keep them private to the
# native module and expose only the N-API registration entry point.
target_link_options(iroh_hos PRIVATE "-Wl,--exclude-libs,ALL")
