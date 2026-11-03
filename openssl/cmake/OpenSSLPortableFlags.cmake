include_guard(GLOBAL)

# Pure argv adapter. flags_variable names a list of compiler tokens, not
# Configure switches. Return one Configure argument beginning with -fPIC so
# Configure's generic flag branch decodes %xx before saving the CFLAGS text.
# Shell quoting is retained for the generated POSIX/MSYS Makefile commands.
function(ossl_portable_encode_flags flags_variable out)
    set(payload "-fPIC")
    foreach(flag IN LISTS ${flags_variable})
        if(flag MATCHES "[\r\n;]" OR flag MATCHES "\\]===\\]")
            message(FATAL_ERROR "Unsupported delimiter in OpenSSL compiler flag")
        endif()
        string(REPLACE "'" "'\\''" quoted "${flag}")
        string(APPEND payload " '${quoted}'")
    endforeach()
    # Escape literal percent first: a literal %20 must survive one upstream
    # decoding pass instead of becoming a space inside the compiler argument.
    string(REPLACE "%" "%25" payload "${payload}")
    string(REPLACE " " "%20" payload "${payload}")
    set(${out} "${payload}" PARENT_SCOPE)
endfunction()
