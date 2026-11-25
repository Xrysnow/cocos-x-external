include(CheckIncludeFile)
include(CheckTypeSize)
include(CMakePushCheckState)
include(CMakePackageConfigHelpers)

set(zlib_version 1.4)
set(zlib_include_dir "${CMAKE_CURRENT_SOURCE_DIR}/src")
set(zlib_sources
    src/adler32.c
    src/compress.c
    src/crc32.c
    src/deflate.c
    src/gzclose.c
    src/gzlib.c
    src/gzread.c
    src/gzwrite.c
    src/infback.c
    src/inffast.c
    src/inflate.c
    src/inftrees.c
    src/trees.c
    src/uncompr.c
    src/zutil.c
)

if(WIN32)
    add_library(dep_zlib SHARED ${zlib_sources} src/win32/zlib.def)
    # Preserve the runtime and import-library names for existing consumers.
    set_target_properties(dep_zlib PROPERTIES
        RUNTIME_OUTPUT_NAME zlib1
        ARCHIVE_OUTPUT_NAME zlib
        PREFIX ""
        IMPORT_PREFIX ""
        DEBUG_POSTFIX ""
    )
else()
    add_library(dep_zlib STATIC ${zlib_sources})
    # Shared dependencies such as FFmpeg can use the platform's zlib.
    set_target_properties(dep_zlib PROPERTIES
        OUTPUT_NAME z
        POSITION_INDEPENDENT_CODE ON
        C_VISIBILITY_PRESET hidden
    )
endif()
configure_target_outdir(dep_zlib)
add_library(ZLIB::ZLIB ALIAS dep_zlib)

cmake_push_check_state(RESET)
check_include_file(unistd.h COCOS_ZLIB_HAVE_UNISTD_H)
set(CMAKE_REQUIRED_DEFINITIONS -D_LARGEFILE64_SOURCE=1)
check_type_size(off64_t COCOS_ZLIB_OFF64_T LANGUAGE C)
cmake_pop_check_state()

target_include_directories(dep_zlib SYSTEM PUBLIC "${zlib_include_dir}")
target_compile_features(dep_zlib PRIVATE c_std_99)
target_compile_definitions(dep_zlib PRIVATE
    ZLIB_BUILD
    $<$<BOOL:${COCOS_ZLIB_HAVE_UNISTD_H}>:HAVE_UNISTD_H=1>
)
if(HAVE_COCOS_ZLIB_OFF64_T)
    target_compile_definitions(dep_zlib PUBLIC _LARGEFILE64_SOURCE=1)
endif()

# Clear the legacy paths before redirecting find_package calls from consumers.
foreach(variable ZLIB_INCLUDE_DIR ZLIB_LIBRARY ZLIB_LIBRARY_DEBUG ZLIB_LIBRARY_RELEASE)
    unset(${variable} CACHE)
endforeach()
configure_file(ZLIBConfig.cmake.in
    "${CMAKE_FIND_PACKAGE_REDIRECTS_DIR}/ZLIBConfig.cmake" @ONLY)
write_basic_package_version_file("${CMAKE_FIND_PACKAGE_REDIRECTS_DIR}/ZLIBConfigVersion.cmake"
    VERSION "${zlib_version}" COMPATIBILITY SameMajorVersion)
