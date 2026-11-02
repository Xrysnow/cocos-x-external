include_guard(GLOBAL)

# Fixed, reviewed Configure options. Source pruning and algorithm/provider
# removal are separate work; every profile still requires the full snapshot.
function(ossl_profile_options profile out)
    set(options)
    if(profile STREQUAL "peripheral-pki" OR profile STREQUAL "peripheral")
        list(APPEND options no-cmp no-cms no-ts)
    elseif(NOT profile STREQUAL "full")
        message(FATAL_ERROR "Unknown OpenSSL profile '${profile}'; use full, peripheral-pki or peripheral")
    endif()
    if(profile STREQUAL "peripheral")
        list(APPEND options no-dtls no-srtp no-quic no-engine no-async no-nextprotoneg no-comp)
    endif()
    set(${out} "${options}" PARENT_SCOPE)
endfunction()
