
set(lib_name zlib)
set(target_name dep_${lib_name})

project(${lib_name})

include("../cmake/CocosExternalConfig.cmake")

if(IOS)
  # The legacy arm64 archive contains device objects, not a simulator slice.
  # Resolve both headers and the link stub from the explicitly selected SDK.
  execute_process(COMMAND xcrun --sdk "${CMAKE_OSX_SYSROOT}" --show-sdk-path
    OUTPUT_VARIABLE zlib_ios_sdk OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
  find_library(zlib_ios_library NAMES z PATHS "${zlib_ios_sdk}/usr/lib"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH NO_CACHE REQUIRED)
  if(NOT EXISTS "${zlib_ios_sdk}/usr/include/zlib.h")
    message(FATAL_ERROR "The selected iOS SDK does not provide zlib headers")
  endif()
  set(ZLIB_INCLUDE_DIR "${zlib_ios_sdk}/usr/include" CACHE PATH "zlib SDK include dir" FORCE)
  foreach(variable ZLIB_LIBRARY ZLIB_LIBRARY_DEBUG ZLIB_LIBRARY_RELEASE)
    set(${variable} "${zlib_ios_library}" CACHE FILEPATH "zlib SDK library" FORCE)
  endforeach()
  add_library(${target_name} UNKNOWN IMPORTED GLOBAL)
  set_target_properties(${target_name} PROPERTIES
    IMPORTED_LOCATION "${zlib_ios_library}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}")
  return()
endif()

if(WINDOWS)
  add_library(${target_name} SHARED IMPORTED GLOBAL)
else()
  add_library(${target_name} STATIC IMPORTED GLOBAL)
endif()

set(ZLIB_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include" CACHE STRING "zlib include dir" FORCE)

if(NOT WINDOWS)
  set(zlib_bundled_library "${platform_spec_path}/libz.a")
  set_target_properties(${target_name} PROPERTIES
    IMPORTED_LOCATION "${zlib_bundled_library}"
  )
else()
  set(zlib_bundled_library "${platform_spec_path}/zlib.lib")
  set_target_properties(${target_name} PROPERTIES
    IMPORTED_LOCATION "${platform_spec_path}/zlib1.dll"
    IMPORTED_IMPLIB "${zlib_bundled_library}"
  )
endif()

# FindZLIB creates an imported target for dependency probes. Keep its Debug
# and Release link locations aligned with the same library as dep_zlib.
foreach(variable ZLIB_LIBRARY ZLIB_LIBRARY_DEBUG ZLIB_LIBRARY_RELEASE)
  set(${variable} "${zlib_bundled_library}" CACHE FILEPATH "Bundled zlib library" FORCE)
endforeach()

set_target_properties(${target_name} PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
