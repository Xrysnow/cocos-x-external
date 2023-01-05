
set(lib_name md5)
set(target_name ${lib_name})

project(${lib_name})

set(${target_name}_src
  md5.c
)

add_library(${target_name} STATIC
  ${${target_name}_src}
)

target_include_directories(${target_name} PUBLIC ..)
