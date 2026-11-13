# cocos-x external dependency build integration

This document describes how cocos-x selects and builds the dependencies listed in
[README.md](README.md). Configure through the parent cocos-x CMake project, which
supplies platform detection, helper functions and feature options; this directory
is not a standalone build entry point.

## Source layout

Source submodules are pinned by this repository's Git tree; see
[.gitmodules](.gitmodules). OpenSSL instead uses the bundled, pruned source snapshot
in `openssl/src/`. The adapters keep their private source copies and outputs in the
build tree rather than modifying upstream source worktrees.

The dependency directory keeps its own library-type and language-standard settings.
Enabling the parent core DLL option does not make every dependency shared.

## Dependency selection

| Dependency | Build and platform selection |
| --- | --- |
| curl | Static source build through [cmake/BuildCurl.cmake](cmake/BuildCurl.cmake), using the project's OpenSSL and zlib targets rather than legacy curl prebuilt libraries. |
| libjpeg-turbo | Separate source build through [cmake/BuildJpegTurbo.cmake](cmake/BuildJpegTurbo.cmake); only the static libjpeg API library is enabled, with SIMD. TurboJPEG, tools and tests are disabled. |
| LuaJIT | Official `LuaJIT/` source submodule, enabled by `BUILD_LUA_LIBS`; see the configuration constraints below. |
| OpenSSL | Bundled source build: shared DLLs on Windows, static PIC libraries on supported Linux, Android and Apple targets. Windows uses `no-module` with default and legacy providers built into libcrypto. |
| FreeType | Linux uses system FreeType 2.11 or newer. Other platforms build the bundled 2.14.3 sources when `BUILD_EXT_FREETYPE=ON`. |
| libpng | Built from the bundled sources on all platforms; Android also links the bundled CPU feature helper. |
| zlib | Bundled prebuilt libraries, except on iOS, where headers and `libz` come from the explicitly selected device or simulator SDK. |
| FFmpeg | Imported prebuilt shared libraries when the parent `CC_ENABLE_VIDEO_TEXTURE` option is enabled. Apple uses `ffmpeg-prebuilt/apple/FFmpeg.xcframework` and its matching headers. |
| OpenAL Soft | Source submodule. Apple builds use an OpenAL framework by default. Android explicitly enables and requires the bundled Oboe backend. |
| Oboe | Android library source subset in `oboe/`; upstream samples and tooling are not included. |
| Glad | Built on Windows, Linux and Android for the gfx GL/EGL paths. |
| glslang | Shader libraries are enabled; command-line binaries, external projects and optimizer support are disabled by this adapter. |
| SPIRV-Cross | Builds the shader translation/reflection libraries; the CLI and tests are disabled. |
| yasio | Static source library requiring C++20, with the project's OpenSSL backend. |
| TinyXML-2 | Built when `BUILD_EXT_TINYXML2=ON`. |
| XXTEA | Built when `BUILD_EXT_XXTEA=ON`. |
| WebSocket parser | Bundled C framing parser, built as the `websocket-parser` target. |

For OpenSSL toolchain settings, build configurations and platform adapter limits,
see [openssl/README.md](openssl/README.md).

## Lua dependencies

[cmake/BuildLuaJIT.cmake](cmake/BuildLuaJIT.cmake) builds a private copy of the
pinned LuaJIT source when `BUILD_LUA_LIBS=ON`. The wrapper supports Debug and Release.
Native MSVC Windows builds produce a DLL; supported POSIX targets use a static
library. Apple targets require a native macOS host, one architecture and an explicit
SDK and deployment target. iOS builds use LuaJIT's interpreter mode, with host
build tools compiled against the macOS SDK. Android's LuaJIT adapter accepts
`arm64-v8a` and `x86_64`.

The current yasio Lua adapter includes `sol/sol.hpp` (3.5.0). The older
`lua/sol2/` copy (2.20.6) remains a legacy snapshot. Header inventories do not
imply that both versions are active library targets.

## Rendering and job-system dependencies

The gfx source is maintained at `cocos-x/cocos/gfx/`, not as an external
submodule. glslang and SPIRV-Cross remain in this repository as shader dependencies.

Taskflow 3.3.0 headers supply `USE_JOB_SYSTEM_TASKFLOW`; bundled CUDA/SYCL headers
do not imply that those GPU backends are enabled. The optional TBB CMake branch
references `external/tbb/`, which is not included in this checkout, so that branch
cannot be selected with the bundled inventory alone.

PVRVFrame retains Windows libraries only; its macOS libraries have been removed.
It is not the default gfx backend.

## Filesystem compatibility headers

`cocos/base/filesystem.h` retains a GHC filesystem fallback for deployment targets
below iOS 13 or NDK versions below 22. Current cocos-x toolchain minimums use
`std::filesystem`; GHC is not an iOS-device-only dependency.

Other header snapshots, including flatbuffers and minimp3, are listed in the
inventory without necessarily defining a separate CMake library target.
