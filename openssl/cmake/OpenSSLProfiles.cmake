include_guard(GLOBAL)

# Feature selection is independent of the physical source layout.
function(ossl_profile_options profile out)
    set(options)
    if(profile STREQUAL "peripheral-pki" OR profile STREQUAL "peripheral")
        list(APPEND options no-cmp no-cms no-ts)
    elseif(NOT profile STREQUAL "full")
        message(FATAL_ERROR "Unknown OpenSSL profile '${profile}'; use full, peripheral-pki or peripheral")
    endif()
    if(profile STREQUAL "peripheral")
        list(APPEND options no-dtls no-srtp no-quic no-engine no-async no-nextprotoneg no-comp)
        # These upstream defaults are explicit because the pruned layout omits
        # their implementations; no additional enabled library feature is lost.
        list(APPEND options no-fips no-md2 no-rc5)
    endif()
    set(${out} "${options}" PARENT_SCOPE)
endfunction()

function(ossl_configure_options profile build_tests build_demos out)
    ossl_profile_options("${profile}" options)
    if(NOT build_tests)
        # The dependency builds libraries only. Full-source test runs retain
        # apps because upstream tests invoke the command-line program.
        list(APPEND options no-apps no-tests no-docs no-fuzz-afl no-fuzz-libfuzzer)
    endif()
    if(NOT build_demos)
        list(APPEND options no-demos)
    endif()
    set(${out} "${options}" PARENT_SCOPE)
endfunction()
