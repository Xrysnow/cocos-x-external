project(external)

option(BUILD_EXT_BOX2D "Build with internal Box2D support" ON)
option(BUILD_EXT_CHIPMUNK "Build with internal chipmunk support" ON)
option(BUILD_EXT_FREETYPE "Build with internal freetype support" ON)
option(BUILD_EXT_RECAST "Build with internal recast support" ON)
option(BUILD_EXT_BULLET "Build with internal bullet support" ON)
option(BUILD_EXT_JPEG "Build with internal jpeg support" ON)
option(BUILD_EXT_OPENSSL "Build with internal openssl support" ON)
# option(BUILD_EXT_UV "Build with internal uv support" ON)
option(BUILD_EXT_WEBP "Build with internal webp support" ON)
# option(BUILD_EXT_WEBSOCKETS "Build with internal websockets support" ON)
option(BUILD_EXT_TINYXML2 "Build with internal tinyxml2 support" ON)
option(BUILD_EXT_PUGIXML "Build with internal pugixml support" ON)
option(BUILD_EXT_XXHASH "Build with internal xxhash support" ON)
option(BUILD_EXT_XXTEA "Build with internal xxtea support" ON)
option(BUILD_EXT_CLIPPER "Build with internal clipper support" ON)
# option(BUILD_EXT_EDTAA3FUNC "Build with internal edtaa3func support" ON)
option(BUILD_EXT_CONVERTUTF "Build with internal ConvertUTF support" ON)
option(BUILD_EXT_POLY2TRI "Build with internal poly2tri support" ON)
option(BUILD_EXT_MD5 "Build with internal md5 support" ON)
option(BUILD_EXT_ZLIB "Build with internal zlib support" ON)
option(BUILD_EXT_CURL "Build with internal curl support" ON)
option(BUILD_EXT_UNZIP "Build with internal unzip support" ON)
option(BUILD_EXT_ASTC "Build with internal ASTC support" ON)
option(BUILD_EXT_LLHTTP "Build with lhttp support" ON)

add_library(external empty.cpp)

# by default, enable ios,macOS openal-soft framework for legal license LGPL-2.1
option(ALSOFT_OSX_FRAMEWORK "" ON)

set(ANDROID_SHARED_LOADS "" CACHE INTERNAL "The android shared libraries load source code" )
set(ANDROID_SHARED_LOAD_FILE_NAME "SharedLoader.java" CACHE INTERNAL "The android shared load java file name" )
set(ANDROID_SHARED_LOAD_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${ANDROID_SHARED_LOAD_FILE_NAME}.in" CACHE INTERNAL "The android shared libraries load config code file" )

function(configure_target_outdir target)
    set_target_properties(${target} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
        FOLDER "External"
    )
    if(APP_NAME)
        set_target_properties(${target} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/${APP_NAME}"
        )
    endif()
endfunction()

function(add_and_configure dir target)
    add_subdirectory(${dir})
    target_link_libraries(external ${target})
    configure_target_outdir(${target})
    use_cocos2dx_compile_options(${target})
    if(XCODE OR VS)
        cocos_mark_code_files(${target})
    endif()
endfunction()

# header only libs
target_include_directories(external
    INTERFACE "robin-map/include"
)
if (ANDROID)
    target_include_directories(external
        INTERFACE "jni.hpp/include"
    )
endif()
target_include_directories(external
    INTERFACE "fmt/include"
)

# cpufeatures
if(ANDROID)
    add_subdirectory(android-specific/cpufeatures)
endif()

add_subdirectory(zlib)
target_link_libraries(external dep_zlib)

# libpng
add_subdirectory(png)
target_include_directories(png PRIVATE "zlib/include")
if(ANDROID)
    target_include_directories(png PRIVATE ${cpufeatures_include_dir})
    target_link_libraries(png INTERFACE cpufeatures)
endif()
target_link_libraries(external png)
configure_target_outdir(png)
set(PNG_PNG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/png" CACHE STRING "png include dir" FORCE)
set(PNG_LIBRARY "png" CACHE STRING "png include dir" FORCE)

if(BUILD_EXT_BOX2D)
    set(BOX2D_BUILD_UNIT_TESTS OFF CACHE BOOL "Build the Box2D unit tests" FORCE)
    set(BOX2D_BUILD_TESTBED OFF CACHE BOOL "Build the Box2D testbed" FORCE)
    add_and_configure(box2d box2d)
endif()

if(BUILD_EXT_CHIPMUNK)
    set(CP_BUILD_SHARED OFF CACHE BOOL "Build chipmunk as shared library" FORCE)
    set(CP_BUILD_STATIC ON CACHE BOOL "Build chipmunk as static library" FORCE)
    set(CP_BUILD_DEMOS OFF CACHE BOOL "Build chipmunk demos" FORCE)
    set(CP_INSTALL_STATIC OFF CACHE BOOL "Install chipmunk static" FORCE)
    add_subdirectory(chipmunk)
    set_target_properties(chipmunk PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/chipmunk/include"
    )

    # !important no double precision
    target_compile_definitions(chipmunk PUBLIC CP_USE_CGTYPES=0)
    target_compile_definitions(chipmunk PUBLIC CP_USE_DOUBLES=0)

    #~ include_directories("${CMAKE_CURRENT_SOURCE_DIR}/chipmunk/include")
    target_link_libraries(external chipmunk)
    configure_target_outdir(chipmunk)
endif()

if(BUILD_EXT_FREETYPE)
    if (NOT LINUX)
        set(FT_WITH_ZLIB ON CACHE BOOL "Use system zlib instead of internal library." FORCE)
        set(DISABLE_FORCE_DEBUG_POSTFIX ON CACHE BOOL "" FORCE)
        set(SKIP_INSTALL_ALL TRUE CACHE BOOL "Skip freetype instal." FORCE)
        set(FT_DISABLE_HARFBUZZ TRUE CACHE BOOL "Disable HarfBuzz." FORCE)
        set(FT_DISABLE_BROTLI TRUE CACHE BOOL "Disable Brotli." FORCE)
        add_subdirectory(freetype)
        target_link_libraries(external freetype)
        configure_target_outdir(freetype)
    endif()
    target_include_directories(external PUBLIC "freetype/include")
endif()

if(BUILD_EXT_RECAST)
    add_and_configure(recast recast)
endif()

if(BUILD_EXT_BULLET)
    add_and_configure(bullet bullet)
endif()

if(BUILD_EXT_JPEG)
    add_subdirectory(jpeg)
    target_link_libraries(external jpeg)
endif()

if(BUILD_EXT_OPENSSL)
    add_subdirectory(openssl)
    if(ANDROID OR LINUX)
        target_link_libraries(OpenSSL::SSL INTERFACE OpenSSL::Crypto)
        target_link_libraries(external OpenSSL::SSL)
    else()
        target_link_libraries(external OpenSSL::Crypto OpenSSL::SSL)
    endif()
    target_compile_definitions(external PUBLIC OPENSSL_SUPPRESS_DEPRECATED=1)
endif()

if(BUILD_EXT_WEBP)
    add_and_configure(webp webp)
endif()

if(BUILD_EXT_TINYXML2)
    add_and_configure(tinyxml2 tinyxml2)
endif()

if(BUILD_EXT_PUGIXML)
    add_and_configure(pugixml pugixml)
endif()

add_and_configure(xxhash xxhash)

add_and_configure(lz4 lz4)

if(BUILD_EXT_XXTEA)
    add_and_configure(xxtea xxtea)
endif()

if(BUILD_EXT_CLIPPER)
    add_and_configure(clipper2 clipper2)
endif()

# if(BUILD_EXT_EDTAA3FUNC)
#     add_subdirectory(edtaa3func)
#     target_link_libraries(external ext_edtaa3func)
# endif()

if(BUILD_EXT_CONVERTUTF)
    add_and_configure(ConvertUTF ConvertUTF)
endif()

if(BUILD_EXT_POLY2TRI)
    add_and_configure(poly2tri poly2tri)
    # Build static lib
    target_compile_definitions(poly2tri PUBLIC P2T_STATIC_EXPORTS)
endif()

if(BUILD_EXT_ASTC)
    add_and_configure(astc astc)
endif()

if(BUILD_EXT_MD5)
    add_and_configure(md5 md5)
endif()

# use lua/js specific libs by property to prevent conflict
if(BUILD_LUA_LIBS)
    add_subdirectory(lua/luajit)
    add_subdirectory(lua/tolua)
    add_subdirectory(lua/lua-cjson)
    configure_target_outdir(luajit)
    configure_target_outdir(tolua)
    configure_target_outdir(lua-cjson)
    set_property(TARGET external APPEND PROPERTY 
        CC_LUA_DEPEND luajit tolua lua-cjson
    )
    target_compile_definitions(lua-cjson PRIVATE USING_LUAJIT=1)
endif()

add_subdirectory(curl)
if(ANDROID OR LINUX)
    target_link_libraries(libcurl INTERFACE OpenSSL::SSL)
endif()
target_link_libraries(external libcurl)

# if(ANDROID)
#     add_subdirectory(android-specific/pvmp3dec)
#     add_subdirectory(android-specific/tremolo)
#     target_link_libraries(external 
#         ext_pvmp3dec 
#         ext_tremolo
#     )
# endif()

# openal-soft(LGPL 2.1)
set(ALSOFT_DLOPEN OFF CACHE BOOL "Check for the dlopen API for loading optional libs" FORCE)
set(ALSOFT_UTILS OFF CACHE BOOL "Build utility program" FORCE)
set(ALSOFT_EXAMPLES OFF CACHE BOOL "Build example programs" FORCE)
set(ALSOFT_INSTALL OFF CACHE BOOL "Install main library" FORCE)
add_subdirectory(openal EXCLUDE_FROM_ALL)
configure_target_outdir(common)
configure_target_outdir(OpenAL)
target_link_libraries(external OpenAL)
if(ANDROID)
    set(ANDROID_SHARED_LOADS "${ANDROID_SHARED_LOADS}System.loadLibrary(\"openal\");" CACHE INTERNAL "Android Shared Loads" )
endif()

add_and_configure(ogg ogg)

if(WINDOWS OR LINUX)
    add_and_configure(glad glad)
endif()

if(WINDOWS OR MACOSX OR LINUX)
    set(GLFW_BUILD_DOCS OFF CACHE BOOL "Build the GLFW documentation" FORCE)
    set(GLFW_INSTALL OFF CACHE BOOL "Build the GLFW documentation" FORCE)
    add_subdirectory(glfw)
    configure_target_outdir(glfw)
    set_target_properties(glfw PROPERTIES OUTPUT_NAME glfw)
    target_link_libraries(external glfw)
    if(NOT WINDOWS)
        target_link_libraries(external pthread)
    endif()
    target_include_directories(external PUBLIC "glfw/include/GLFW")
endif()

# unzip depend on zlib
if(BUILD_EXT_UNZIP)
    add_and_configure(unzip unzip)
endif()

if(BUILD_EXT_LLHTTP)
    add_and_configure(llhttp llhttp)
endif()

if(CC_USE_GFX)
    # glslang
    set(BUILD_EXTERNAL OFF CACHE BOOL "Build external dependencies in /External" FORCE)
    set(ENABLE_GLSLANG_BINARIES OFF CACHE BOOL "Builds glslangValidator and spirv-remap" FORCE)
    set(ENABLE_RTTI ON CACHE BOOL "Enables RTTI" FORCE)
    set(ENABLE_CTEST OFF CACHE BOOL "Enables testing" FORCE)
    add_subdirectory(glslang)
    target_link_libraries(external SPVRemapper SPIRV HLSL glslang MachineIndependent OGLCompiler OSDependent GenericCodeGen)

    # spirv-cross
    set(SPIRV_CROSS_CLI OFF CACHE BOOL "Build the CLI binary. Requires SPIRV_CROSS_STATIC." FORCE)
    set(SPIRV_CROSS_ENABLE_TESTS OFF CACHE BOOL "Enable SPIRV-Cross tests." FORCE)
    set(SPIRV_CROSS_SKIP_INSTALL OFF CACHE BOOL "Skips installation targets." FORCE)
    add_subdirectory(spirv_cross)
    target_link_libraries(external spirv-cross-c spirv-cross-util spirv-cross-hlsl spirv-cross-msl spirv-cross-reflect spirv-cross-cpp spirv-cross-glsl spirv-cross-core)

    if(USE_JOB_SYSTEM_TBB)        
        # tbb
        set(TBB_BUILD_SHARED OFF CACHE BOOL "Build TBB shared library" FORCE)
        set(TBB_BUILD_TESTS OFF CACHE BOOL "Build TBB tests and enable testing infrastructure" FORCE)
        set(TBB_INSTALL_TARGETS OFF CACHE BOOL "Include build targets for 'make install'" FORCE)
        add_subdirectory(tbb)
        target_link_libraries(external tbb_static tbbmalloc_static tbbmalloc_proxy_static)
    endif()

    # gfx
    add_subdirectory(gfx)
    target_link_libraries(external ext_gfx)

    set(libs_to_config
        SPVRemapper
        SPIRV
        HLSL
        glslang
        MachineIndependent
        OGLCompiler
        OSDependent
        GenericCodeGen
        spirv-cross-c
        spirv-cross-util
        spirv-cross-hlsl
        spirv-cross-msl
        spirv-cross-reflect
        spirv-cross-cpp
        spirv-cross-glsl
        spirv-cross-core
        ext_gfx
    )

    if(USE_JOB_SYSTEM_TBB)
        list(APPEND libs_to_config
            tbb_static
            tbbmalloc_static
            tbbmalloc_proxy_static
            tbb_def_files
        )
    endif()

    foreach(_lib ${libs_to_config})
        configure_target_outdir(${_lib})
    endforeach()
endif()

# put "external" into External folder, too
configure_target_outdir(external)

if(MACOSX OR IOS)
    add_subdirectory(glsl-optimizer)
    target_link_libraries(external 
        ext_glcpp_library
        ext_glsl_optimizer
        ext_libmesa
    )
endif()

if (ANDROID)
    function(config_android_shared_libs package_name target_folder)
        string(REPLACE "." "/" package_path ${package_name})
        set(ANDROID_PACKAGE_NAME ${package_name})
        configure_file(${ANDROID_SHARED_LOAD_FILE_PATH} ${target_folder}/${package_path}/${ANDROID_SHARED_LOAD_FILE_NAME} @ONLY)
    endfunction()
endif()
