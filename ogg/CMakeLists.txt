
set(lib_name ogg)
set(target_name ${lib_name})

project(${target_name})

set(OGG_SRC_ROOT ${CMAKE_CURRENT_LIST_DIR}/src)
set(${target_name}_src
  ${OGG_SRC_ROOT}/ogg/bitwise.c
  ${OGG_SRC_ROOT}/ogg/framing.c
  ${OGG_SRC_ROOT}/vorbis/analysis.c
  ${OGG_SRC_ROOT}/vorbis/bitrate.c
  ${OGG_SRC_ROOT}/vorbis/block.c
  ${OGG_SRC_ROOT}/vorbis/codebook.c
  ${OGG_SRC_ROOT}/vorbis/envelope.c
  ${OGG_SRC_ROOT}/vorbis/floor0.c
  ${OGG_SRC_ROOT}/vorbis/floor1.c
  ${OGG_SRC_ROOT}/vorbis/info.c
  ${OGG_SRC_ROOT}/vorbis/lookup.c
  ${OGG_SRC_ROOT}/vorbis/lpc.c
  ${OGG_SRC_ROOT}/vorbis/lsp.c
  ${OGG_SRC_ROOT}/vorbis/mapping0.c
  ${OGG_SRC_ROOT}/vorbis/mdct.c
  ${OGG_SRC_ROOT}/vorbis/psy.c
  ${OGG_SRC_ROOT}/vorbis/registry.c
  ${OGG_SRC_ROOT}/vorbis/res0.c
  ${OGG_SRC_ROOT}/vorbis/sharedbook.c
  ${OGG_SRC_ROOT}/vorbis/smallft.c
  ${OGG_SRC_ROOT}/vorbis/synthesis.c
  ${OGG_SRC_ROOT}/vorbis/vorbisenc.c
  ${OGG_SRC_ROOT}/vorbis/vorbisfile.c
  ${OGG_SRC_ROOT}/vorbis/window.c
)

add_library(${target_name} STATIC
  ${${target_name}_src}
)

target_include_directories(${target_name}
  PUBLIC "${CMAKE_CURRENT_LIST_DIR}/include"
  PRIVATE "${CMAKE_CURRENT_LIST_DIR}/src/vorbis"
)
