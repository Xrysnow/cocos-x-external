
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

target_include_directories(${target_name} PRIVATE ../luajit/include)

target_include_directories(${target_name} PUBLIC .)
