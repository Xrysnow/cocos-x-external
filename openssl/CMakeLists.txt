# Every supported platform builds the pinned source; no precompiled fallback.
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    include("${CMAKE_CURRENT_LIST_DIR}/../cmake/OpenSSLConsumers.cmake")
elseif(ANDROID OR CMAKE_SYSTEM_NAME MATCHES "^(Linux|Darwin|iOS|tvOS)$")
    include("${CMAKE_CURRENT_LIST_DIR}/../cmake/OpenSSLPortableConsumers.cmake")
else()
    message(FATAL_ERROR "OpenSSL source build is not implemented for '${CMAKE_SYSTEM_NAME}'; no precompiled libraries are available")
endif()
