
set(lib_name xxtea)
set(target_name ${lib_name})

project(${lib_name})

add_library(${target_name} STATIC
  xxtea.cpp
)

target_include_directories(${target_name} PUBLIC .)
