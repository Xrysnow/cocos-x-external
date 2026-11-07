# yasio v4.4.1, a7c8428fec7aaccf20b0ee8cc6cdc88aad5d4d3b.
# Keep upstream sources unmodified and share one compiled implementation.
add_library(yasio STATIC io_service.cpp xxsocket.cpp)
set_target_properties(yasio PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(yasio PUBLIC "${CMAKE_CURRENT_LIST_DIR}/..")
target_compile_features(yasio PUBLIC cxx_std_20)
target_compile_definitions(yasio PUBLIC YASIO_SSL_BACKEND=1)
target_link_libraries(yasio PUBLIC OpenSSL::SSL)
if(WIN32)
    target_link_libraries(yasio PUBLIC ws2_32)
elseif(ANDROID)
    target_link_libraries(yasio PUBLIC log)
endif()
