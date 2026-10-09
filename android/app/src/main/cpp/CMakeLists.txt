# Native OpenVPN 3 client for OpenIPTV (Power User Tools, #41).
# Sources come from OVPN_DEPS (fetched by android/openvpn-deps.sh; not
# committed): openvpn3 (MPL-2.0 option), asio (BSL-1.0, OpenVPN's patches),
# fmt (MIT), lz4 (BSD-2), xxHash (BSD-2), mbed TLS (Apache-2.0).
cmake_minimum_required(VERSION 3.18)
project(openiptv_ovpn CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (NOT DEFINED OVPN_DEPS)
  message(FATAL_ERROR "OVPN_DEPS not set — run android/openvpn-deps.sh")
endif ()

# mbed TLS: static, library only.
set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(MBEDTLS_FATAL_WARNINGS OFF CACHE BOOL "" FORCE)
set(USE_SHARED_MBEDTLS_LIBRARY OFF CACHE BOOL "" FORCE)
add_subdirectory(${OVPN_DEPS}/mbedtls ${CMAKE_BINARY_DIR}/mbedtls EXCLUDE_FROM_ALL)

add_library(lz4_static STATIC ${OVPN_DEPS}/lz4/lib/lz4.c)
target_include_directories(lz4_static PUBLIC ${OVPN_DEPS}/lz4/lib)

add_library(openiptv_ovpn SHARED
  openvpn_jni.cpp
  ${OVPN_DEPS}/openvpn3/openvpn/crypto/data_epoch.cpp)

target_include_directories(openiptv_ovpn PRIVATE
  ${OVPN_DEPS}/asio/include          # patched asio first
  ${OVPN_DEPS}/openvpn3
  ${OVPN_DEPS}/fmt/include
  ${OVPN_DEPS}/xxHash)

target_compile_definitions(openiptv_ovpn PRIVATE
  ASIO_STANDALONE USE_ASIO HAVE_LZ4 USE_MBEDTLS FMT_HEADER_ONLY
  OPENVPN_CORE_API_VISIBILITY_HIDDEN)

target_compile_options(openiptv_ovpn PRIVATE
  -fexceptions -frtti -Wno-deprecated-declarations -Wno-unused-parameter)

target_link_libraries(openiptv_ovpn
  mbedtls mbedx509 mbedcrypto lz4_static log)

# 16 KB page alignment (Android 15+ devices).
target_link_options(openiptv_ovpn PRIVATE "-Wl,-z,max-page-size=16384")
