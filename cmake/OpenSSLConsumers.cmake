include_guard(GLOBAL)

# Native Windows consumer migration. Other platforms retain their existing
# precompiled entry until their source-build toolchains are implemented.
if(NOT CMAKE_CONFIGURATION_TYPES STREQUAL "Debug;Release" AND NOT CMAKE_CONFIGURATION_TYPES STREQUAL "Debug")
    message(FATAL_ERROR "OpenSSL consumers require -DCMAKE_CONFIGURATION_TYPES=Debug;Release or Debug")
endif()
if(NOT CC_OPENSSL_CONSUMER_ID)
    foreach(old_variable OPENSSL_ROOT_DIR OPENSSL_INCLUDE_DIR OPENSSL_CRYPTO_LIBRARY OPENSSL_SSL_LIBRARY
        LIB_EAY_DEBUG LIB_EAY_RELEASE SSL_EAY_DEBUG SSL_EAY_RELEASE
        LIB_EAY_LIBRARY_DEBUG LIB_EAY_LIBRARY_RELEASE SSL_EAY_LIBRARY_DEBUG SSL_EAY_LIBRARY_RELEASE)
        if(${old_variable})
            message(FATAL_ERROR "This cache contains an older OpenSSL selection. Use a new build directory or cmake --fresh; cached consumer probes must not be reused.")
        endif()
    endforeach()
endif()
set(CMAKE_TRY_COMPILE_CONFIGURATION Debug CACHE STRING "Configuration used for dependency link probes")
if(NOT CMAKE_TRY_COMPILE_CONFIGURATION IN_LIST CMAKE_CONFIGURATION_TYPES)
    message(FATAL_ERROR "CMAKE_TRY_COMPILE_CONFIGURATION must be one of the prepared configurations")
endif()

set(CC_OPENSSL_SOURCE_DIR "" CACHE PATH "Local full OpenSSL 3.5.9 source snapshot")
set(CC_OPENSSL_ARCHIVE "" CACHE FILEPATH "Optional local fixed OpenSSL 3.5.9 archive")
if(NOT CC_OPENSSL_SOURCE_DIR)
    if(NOT EXISTS "${CC_OPENSSL_ARCHIVE}")
        message(FATAL_ERROR "Set CC_OPENSSL_SOURCE_DIR to a full local 3.5.9 snapshot, or CC_OPENSSL_ARCHIVE to its fixed local tar.gz; no download is performed.")
    endif()
    set(prepared "${CMAKE_BINARY_DIR}/openssl-inputs")
    if(NOT EXISTS "${prepared}/openssl-3.5.9/Configure")
        execute_process(COMMAND "${CMAKE_COMMAND}" "-DARCHIVE=${CC_OPENSSL_ARCHIVE}"
            "-DDESTINATION=${prepared}" -P "${CMAKE_CURRENT_LIST_DIR}/../openssl/cmake/PrepareSource.cmake"
            RESULT_VARIABLE prepared_result)
        if(NOT prepared_result EQUAL 0)
            message(FATAL_ERROR "Cannot prepare the local OpenSSL snapshot")
        endif()
    endif()
    set(CC_OPENSSL_SOURCE_DIR "${prepared}/openssl-3.5.9" CACHE PATH "Local full OpenSSL 3.5.9 source snapshot" FORCE)
endif()

set(CC_OPENSSL_PROFILE "peripheral" CACHE STRING "OpenSSL feature profile")
include("${CMAKE_CURRENT_LIST_DIR}/BuildOpenSSL.cmake")
cc_build_openssl()
include("${CC_OPENSSL_DEBUG_INPUT}")
set(debug_id "${OSSL_ID}")
set(release_id "")
if("Release" IN_LIST CMAKE_CONFIGURATION_TYPES)
    include("${CC_OPENSSL_RELEASE_INPUT}")
    set(release_id "${OSSL_ID}")
endif()
string(SHA256 consumer_id "${debug_id}\n${release_id}\n${CMAKE_TRY_COMPILE_CONFIGURATION}")
if(CC_OPENSSL_CONSUMER_ID AND NOT CC_OPENSSL_CONSUMER_ID STREQUAL consumer_id)
    message(FATAL_ERROR "OpenSSL configuration identity changed. Reconfigure with cmake --fresh (and the same explicit inputs) or use a new build directory so all consumer probes run again.")
endif()
set(CC_OPENSSL_CONSUMER_ID "${consumer_id}" CACHE INTERNAL "OpenSSL identity used for consumer configuration" FORCE)

# Official install_dev refreshes timestamps even when bytes are unchanged.
# Publish verified artifacts without touching unchanged consumer inputs.
set(driver_debug_stage "${CC_OPENSSL_DEBUG_STAGE}")
set(driver_release_stage "${CC_OPENSSL_RELEASE_STAGE}")
set(publisher "${CMAKE_CURRENT_LIST_DIR}/PublishOpenSSL.cmake")
set(publish_base "${CMAKE_BINARY_DIR}/openssl-consumers/${consumer_id}")
set(publish_byproducts)
foreach(name IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "${name}" config)
    set(destination "${publish_base}/${name}/stage")
    execute_process(COMMAND "${CMAKE_COMMAND}" "-DINPUT=${CC_OPENSSL_${config}_INPUT}"
        "-DDESTINATION=${destination}" -P "${publisher}" RESULT_VARIABLE published)
    if(NOT published EQUAL 0)
        message(FATAL_ERROR "Cannot publish verified OpenSSL ${name} consumer artifacts")
    endif()
    set(CC_OPENSSL_${config}_STAGE "${destination}")
    file(STRINGS "${destination}/../stage-manifest.sha256" published_files)
    foreach(record IN LISTS published_files)
        if(record MATCHES "^[0-9a-f]+  (.+)$")
            list(APPEND publish_byproducts "$<$<CONFIG:${name}>:${destination}/${CMAKE_MATCH_1}>")
        endif()
    endforeach()
endforeach()
set(selected_input "${CC_OPENSSL_DEBUG_INPUT}")
set(selected_stage "${CC_OPENSSL_DEBUG_STAGE}")
if("Release" IN_LIST CMAKE_CONFIGURATION_TYPES)
    set(selected_input "$<IF:$<CONFIG:Debug>,${CC_OPENSSL_DEBUG_INPUT},${CC_OPENSSL_RELEASE_INPUT}>")
    set(selected_stage "$<IF:$<CONFIG:Debug>,${CC_OPENSSL_DEBUG_STAGE},${CC_OPENSSL_RELEASE_STAGE}>")
endif()
add_custom_target(cc_openssl_publish
    COMMAND "${CMAKE_COMMAND}"
        "-DINPUT=${selected_input}"
        "-DDESTINATION=${selected_stage}"
        -P "${publisher}"
    BYPRODUCTS ${publish_byproducts} VERBATIM)
add_dependencies(cc_openssl_publish cc_openssl_build)
foreach(component Crypto SSL)
    string(TOLOWER "${component}" library)
    set_target_properties(OpenSSL::${component} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${selected_stage}/include")
    foreach(name IN LISTS CMAKE_CONFIGURATION_TYPES)
        string(TOUPPER "${name}" config)
        set_target_properties(OpenSSL::${component} PROPERTIES
            IMPORTED_LOCATION_${config} "${CC_OPENSSL_${config}_STAGE}/bin/lib${library}-3-x64.dll"
            IMPORTED_IMPLIB_${config} "${CC_OPENSSL_${config}_STAGE}/lib/lib${library}.lib")
    endforeach()
    add_dependencies(OpenSSL::${component} cc_openssl_publish)
endforeach()

# FindOpenSSL uses these additional MSVC cache entries even when the imported
# targets already exist. Replace all of them with this identity's real files.
foreach(name IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "${name}" config)
    set(stage "${CC_OPENSSL_${config}_STAGE}")
    set(LIB_EAY_${config} "${stage}/lib/libcrypto.lib" CACHE FILEPATH "Selected OpenSSL Crypto import library" FORCE)
    set(SSL_EAY_${config} "${stage}/lib/libssl.lib" CACHE FILEPATH "Selected OpenSSL SSL import library" FORCE)
    set(LIB_EAY_LIBRARY_${config} "${stage}/lib/libcrypto.lib" CACHE FILEPATH "Selected OpenSSL Crypto import library" FORCE)
    set(SSL_EAY_LIBRARY_${config} "${stage}/lib/libssl.lib" CACHE FILEPATH "Selected OpenSSL SSL import library" FORCE)
endforeach()
string(TOUPPER "${CMAKE_TRY_COMPILE_CONFIGURATION}" probe_config)
set(probe_stage "${CC_OPENSSL_${probe_config}_STAGE}")
set(OPENSSL_ROOT_DIR "${probe_stage}" CACHE PATH "Selected OpenSSL probe installation" FORCE)
set(OPENSSL_INCLUDE_DIR "${probe_stage}/include" CACHE PATH "Selected OpenSSL public headers" FORCE)
set(OPENSSL_CRYPTO_LIBRARY "${probe_stage}/lib/libcrypto.lib" CACHE FILEPATH "Selected OpenSSL probe library" FORCE)
set(OPENSSL_SSL_LIBRARY "${probe_stage}/lib/libssl.lib" CACHE FILEPATH "Selected OpenSSL probe library" FORCE)
set(OPENSSL_USE_STATIC_LIBS OFF CACHE BOOL "Windows OpenSSL uses shared DLLs" FORCE)
set(OPENSSL_MSVC_STATIC_RT OFF CACHE BOOL "Windows OpenSSL uses the dynamic CRT" FORCE)
set(OPENSSL_VERSION "3.5.9" CACHE INTERNAL "Selected OpenSSL version" FORCE)

# The deployment helper copies modules after the per-configuration driver runs.
set_property(TARGET OpenSSL::Crypto PROPERTY CC_RUNTIME_MODULES
    "${selected_stage}/lib/ossl-modules/legacy.dll;ossl-modules/legacy.dll")
set(stages_json "{\n")
foreach(name IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "${name}" config)
    string(TOLOWER "${name}" lower)
    string(APPEND stages_json "  \"${name}\": \"${CC_OPENSSL_${config}_STAGE}\",\n  \"${name}Input\": \"${CC_OPENSSL_${config}_INPUT}\",\n  \"Driver${name}\": \"${driver_${lower}_stage}\",\n")
endforeach()
file(WRITE "${CMAKE_BINARY_DIR}/openssl-stages.json"
    "${stages_json}  \"ConsumerId\": \"${consumer_id}\",\n  \"ProbeConfiguration\": \"${CMAKE_TRY_COMPILE_CONFIGURATION}\"\n}\n")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_LIST_FILE}" "${publisher}")
message(STATUS "OpenSSL consumers: 3.5.9 shared; profile=${CC_OPENSSL_PROFILE}; probe=${CMAKE_TRY_COMPILE_CONFIGURATION}; identity=${consumer_id}")
