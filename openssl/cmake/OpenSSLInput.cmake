include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/PrepareBundledSource.cmake")

function(ossl_track_source source)
    if(CMAKE_SCRIPT_MODE_FILE)
        return()
    endif()
    # Include directories in the glob so extra/missing empty directories also
    # trigger reconfiguration. File timestamps detect changes to existing bytes.
    file(GLOB_RECURSE entries CONFIGURE_DEPENDS LIST_DIRECTORIES TRUE "${source}/*" "${source}/.*")
    set(files)
    foreach(entry IN LISTS entries)
        if(NOT IS_DIRECTORY "${entry}")
            list(APPEND files "${entry}")
        endif()
    endforeach()
    ossl_add_configure_dependencies(${files})
endfunction()

# Every consumer and standalone platform driver uses the bundled snapshot.
function(ossl_select_input out_source out_bundled)
    # Retire cached selections from older builds; none can override the bundle.
    foreach(name SOURCE_DIR ARCHIVE SOURCE_LAYOUT PROFILE BUILD_TESTS BUILD_DEMOS)
        unset(CC_OPENSSL_${name} CACHE)
    endforeach()
    ossl_resolve_path("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../src" bundled)
    set(prepared "${CMAKE_BINARY_DIR}/openssl-inputs/bundled")
    ossl_prepare_bundled_source("${bundled}" "${prepared}")
    ossl_source_version(OSSL_SOURCE_VERSION)
    set(source "${prepared}/openssl-${OSSL_SOURCE_VERSION}")
    ossl_track_source("${bundled}")
    ossl_validate_source("${source}" pruned peripheral OFF OFF unused_hash unused_inventory)
    ossl_track_source("${source}")
    if(NOT CMAKE_SCRIPT_MODE_FILE)
        ossl_add_configure_dependencies(
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../source-manifest.json"
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../prune-manifest.json"
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../source-executables.txt")
    endif()
    set(${out_source} "${source}" PARENT_SCOPE)
    set(${out_bundled} "${bundled}" PARENT_SCOPE)
endfunction()
