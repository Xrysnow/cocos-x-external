# Upstream requires a standalone build rather than add_subdirectory().
include_guard(GLOBAL)
include(ExternalProject)

function(cocos_build_jpeg_turbo)
    get_filename_component(jpeg_source "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../jpeg-turbo" ABSOLUTE)
    if(NOT EXISTS "${jpeg_source}/CMakeLists.txt")
        message(FATAL_ERROR "Initialize the external/jpeg-turbo submodule before configuring.")
    endif()

    set(jpeg_binary "${CMAKE_CURRENT_BINARY_DIR}/jpeg-turbo")
    set(jpeg_args
        -DENABLE_SHARED:BOOL=OFF
        -DENABLE_STATIC:BOOL=ON
        -DWITH_TURBOJPEG:BOOL=OFF
        -DWITH_TOOLS:BOOL=OFF
        -DWITH_TESTS:BOOL=OFF
        -DWITH_SIMD:BOOL=ON
        -DWITH_CRT_DLL:BOOL=ON
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
        "-DCMAKE_BUILD_TYPE:STRING=$<CONFIG>"
    )

    # ExternalProject does not inherit the parent compiler or cross-compilation settings.
    foreach(variable
        CMAKE_TOOLCHAIN_FILE CMAKE_MAKE_PROGRAM CMAKE_CONFIGURATION_TYPES
        CMAKE_C_COMPILER CMAKE_C_COMPILER_ARG1 CMAKE_C_COMPILER_TARGET
        CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN CMAKE_C_STANDARD CMAKE_C_STANDARD_REQUIRED
        CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
        CMAKE_MSVC_RUNTIME_LIBRARY CMAKE_SYSROOT CMAKE_SYSROOT_COMPILE CMAKE_SYSROOT_LINK
        CMAKE_OSX_SYSROOT CMAKE_OSX_DEPLOYMENT_TARGET
        CMAKE_ANDROID_NDK CMAKE_ANDROID_ARCH_ABI CMAKE_ANDROID_STL_TYPE
        ANDROID_NDK ANDROID_ABI ANDROID_PLATFORM ANDROID_TOOLCHAIN ANDROID_STL
        ANDROID_ARM_MODE ANDROID_ARM_NEON
        PLATFORM DEPLOYMENT_TARGET ENABLE_BITCODE ENABLE_ARC ENABLE_VISIBILITY
        ENABLE_STRICT_TRY_COMPILE NAMED_LANGUAGE_SUPPORT
    )
        if(DEFINED ${variable} AND NOT "${${variable}}" STREQUAL "")
            string(REPLACE ";" "|" value "${${variable}}")
            # Keep expressions such as the MSVC runtime's Debug selection in the child project.
            string(REPLACE "$<" "$<1:$><" value "${value}")
            list(APPEND jpeg_args "-D${variable}:STRING=${value}")
        endif()
    endforeach()
    if(CMAKE_CROSSCOMPILING)
        foreach(variable CMAKE_SYSTEM_NAME CMAKE_SYSTEM_VERSION CMAKE_SYSTEM_PROCESSOR)
            list(APPEND jpeg_args "-D${variable}:STRING=${${variable}}")
        endforeach()
    endif()

    # NASM is a host tool, including when cross-compiling Android on Windows.
    if(CMAKE_ASM_NASM_COMPILER)
        set(jpeg_nasm "${CMAKE_ASM_NASM_COMPILER}")
    elseif(CMAKE_HOST_WIN32 AND EXISTS "${jpeg_source}/../../tools/nasm/nasm.exe")
        get_filename_component(jpeg_nasm "${jpeg_source}/../../tools/nasm/nasm.exe" ABSOLUTE)
    else()
        find_program(jpeg_nasm NAMES nasm yasm NO_CMAKE_FIND_ROOT_PATH)
    endif()
    if(jpeg_nasm)
        list(APPEND jpeg_args "-DCMAKE_ASM_NASM_COMPILER:FILEPATH=${jpeg_nasm}")
        message(STATUS "libjpeg-turbo assembler: ${jpeg_nasm}")
    endif()

    if(MSVC OR CMAKE_C_SIMULATE_ID STREQUAL "MSVC")
        set(jpeg_filename jpeg-static.lib)
    else()
        set(jpeg_filename libjpeg.a)
    endif()
    get_property(jpeg_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(jpeg_multi_config)
        set(jpeg_archive_suffix "/$<CONFIG>/${jpeg_filename}")
    else()
        set(jpeg_archive_suffix "/${jpeg_filename}")
    endif()

    # Upstream rejects multiple Apple architectures in a single build tree.
    # Build each slice independently and combine static archives with lipo.
    set(jpeg_architectures "${CMAKE_OSX_ARCHITECTURES}")
    list(LENGTH jpeg_architectures jpeg_architecture_count)
    if(APPLE AND jpeg_architecture_count GREATER 1)
        set(jpeg_split_architectures TRUE)
    else()
        set(jpeg_architectures default)
    endif()

    set(jpeg_projects)
    set(jpeg_archives)
    foreach(architecture IN LISTS jpeg_architectures)
        set(architecture_args)
        if(jpeg_split_architectures)
            set(child_binary "${jpeg_binary}/${architecture}")
            set(child_target "jpeg-turbo-${architecture}")
        else()
            set(child_binary "${jpeg_binary}")
            set(child_target jpeg-turbo-build)
            set(architecture "${CMAKE_OSX_ARCHITECTURES}")
        endif()
        if(APPLE AND architecture)
            list(APPEND architecture_args
                "-DCMAKE_OSX_ARCHITECTURES:STRING=${architecture}"
                "-DARCHS:STRING=${architecture}"
            )
        endif()
        set(child_archive "${child_binary}${jpeg_archive_suffix}")
        file(MAKE_DIRECTORY "${child_binary}")
        ExternalProject_Add(${child_target}
            SOURCE_DIR "${jpeg_source}"
            BINARY_DIR "${child_binary}"
            PREFIX "${child_binary}/project"
            DOWNLOAD_COMMAND ""
            UPDATE_COMMAND ""
            LIST_SEPARATOR "|"
            CMAKE_ARGS ${jpeg_args} ${architecture_args}
            BUILD_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --config $<CONFIG> --target jpeg-static
            BUILD_BYPRODUCTS "${child_archive}"
            BUILD_ALWAYS TRUE
            INSTALL_COMMAND ""
            LOG_CONFIGURE TRUE
            LOG_BUILD TRUE
            LOG_OUTPUT_ON_FAILURE TRUE
        )
        set_target_properties(${child_target} PROPERTIES FOLDER "External")
        list(APPEND jpeg_projects ${child_target})
        list(APPEND jpeg_archives "${child_archive}")
        if(NOT jpeg_include_binary)
            set(jpeg_include_binary "${child_binary}")
        endif()
    endforeach()

    set(jpeg_archive "${jpeg_binary}${jpeg_archive_suffix}")
    if(jpeg_split_architectures)
        if(CMAKE_LIPO)
            set(jpeg_lipo "${CMAKE_LIPO}")
        else()
            find_program(jpeg_lipo NAMES lipo REQUIRED)
        endif()
        add_custom_command(OUTPUT "${jpeg_archive}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${jpeg_binary}/$<CONFIG>"
            COMMAND "${jpeg_lipo}" -create ${jpeg_archives} -output "${jpeg_archive}"
            DEPENDS ${jpeg_projects} ${jpeg_archives}
            VERBATIM
        )
        add_custom_target(jpeg-turbo-build DEPENDS "${jpeg_archive}")
        set_target_properties(jpeg-turbo-build PROPERTIES FOLDER "External")
    endif()

    # Keep the engine's existing link target and propagate the generated jconfig.h.
    add_library(jpeg STATIC IMPORTED GLOBAL)
    set_target_properties(jpeg PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${jpeg_source}/src;${jpeg_include_binary}"
    )
    if(jpeg_multi_config)
        set_property(TARGET jpeg PROPERTY IMPORTED_CONFIGURATIONS "${CMAKE_CONFIGURATION_TYPES}")
        foreach(configuration IN LISTS CMAKE_CONFIGURATION_TYPES)
            string(TOUPPER "${configuration}" configuration_upper)
            string(REPLACE "$<CONFIG>" "${configuration}" configuration_archive "${jpeg_archive}")
            set_property(TARGET jpeg PROPERTY IMPORTED_LOCATION_${configuration_upper} "${configuration_archive}")
        endforeach()
    else()
        set_property(TARGET jpeg PROPERTY IMPORTED_LOCATION "${jpeg_archive}")
    endif()
    add_dependencies(jpeg jpeg-turbo-build)
endfunction()

cocos_build_jpeg_turbo()
