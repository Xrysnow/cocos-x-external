
set(lib_name tolua)
set(target_name ${lib_name})

project(${lib_name})

set(${target_name}_src
  tolua_event.c
  tolua_is.c
  tolua_map.c
  tolua_push.c
  tolua_to.c
)

add_library(${target_name} STATIC
  ${${target_name}_src}
)

target_include_directories(${target_name} PRIVATE ../luajit/include)
target_include_directories(${target_name} PUBLIC .)
