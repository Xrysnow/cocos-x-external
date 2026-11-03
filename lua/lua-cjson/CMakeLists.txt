
set(lib_name lua-cjson)
set(target_name ${lib_name})

project(${lib_name})

set(${target_name}_src
  fpconv.c
  strbuf.c
  lua_cjson.c
)

add_library(${target_name} STATIC
  ${${target_name}_src}
)

target_link_libraries(${target_name} PUBLIC luajit)

target_include_directories(${target_name} PUBLIC .)
