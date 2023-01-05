
set(lib_name bullet)
set(target_name ${lib_name})

project(${lib_name})

add_library(${target_name} STATIC
  btBulletCollisionAll.cpp
  btBulletDynamicsAll.cpp
  btLinearMathAll.cpp
)
target_include_directories(${target_name} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(${target_name} PUBLIC BT_USE_SSE_IN_API=1)
