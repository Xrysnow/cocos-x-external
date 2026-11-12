# OpenSSL source dependency

`src/` contains a pinned, pruned OpenSSL **3.5.9** source snapshot with no
upstream file modifications. Source identity and pruning rules are recorded in
`source-manifest.json` and `prune-manifest.json`. OpenSSL is licensed under
Apache-2.0; see `src/LICENSE.txt`.

All supported platforms build the bundled source with the `pruned` layout and
`peripheral` feature profile. Apps, tests, docs, demos and fuzzers are disabled.
CMake prepares a private copy in the build directory and runs the official
OpenSSL Configure/Makefile flow without modifying `src/`.

## Platform toolchains

Perl and the target platform's build tools must be available locally.

| Target | Toolchain and output |
| --- | --- |
| Windows | Parent Visual Studio MSVC toolchain, Win32/x64/ARM64; native Perl and nmake (or explicitly selected jom). Project NASM is required for x86/x64. Builds shared DLLs with dynamic CRT and `no-module`; default and legacy providers are built into libcrypto. |
| Linux | Parent compiler, make, ar, ranlib, nm and readelf; x86_64, aarch64, i686 or armv7. Builds static PIC libraries and retains the parent's cross-compilation target, sysroot and flags. |
| Android | NDK arm64-v8a, x86_64, armeabi-v7a or x86; static PIC libraries. Windows hosts require the configured MSYS/Perl/GNU make toolchain. |
| macOS/iOS/tvOS | Native Xcode tools, an explicit SDK, one architecture and deployment target; static PIC libraries. Device and simulator builds use separate target triples and build directories. |

### Toolchain settings

Pass these CMake cache options as `-D<name>=<value>`. Defaults below are those
of the OpenSSL adapter; project entry points may supply explicit values.

| Option | Default | Description |
| --- | --- | --- |
| `CC_OPENSSL_WORK_ROOT` | `${CMAKE_BINARY_DIR}/openssl-work` | Build and staging root on all platforms; keeps prepared sources, build outputs and installed headers/libraries isolated from the bundled source. |
| `CC_OPENSSL_PERL` | Auto-detected | Host Perl executable. Windows targets require native Windows Perl; POSIX hosts require native POSIX Perl. Windows-hosted Android builds use Perl from `CC_OPENSSL_MSYS_ROOT` instead. |
| `CC_OPENSSL_MAKE` | Platform-dependent | Windows targets use nmake from the selected Visual Studio instance; an explicit path must match it. POSIX hosts auto-detect make. Windows-hosted Android builds require an explicit absolute path to an existing native Windows GNU make executable. |
| `CC_OPENSSL_JOBS` | `8` | Maximum compilation parallelism, an integer from `1` through `8`. Applies to jom and portable builds; nmake always uses one job. |
| `CC_OPENSSL_BACKEND` | `nmake` | Windows-target build backend: `nmake` or `jom`. Selecting `jom` enables bounded parallel compilation. |
| `CC_OPENSSL_JOM` | Auto-detected when selected | Absolute path to a local jom executable, used only with `CC_OPENSSL_BACKEND=jom`. Requires jom 1.1.0 or newer; it is never downloaded automatically. |
| `CC_OPENSSL_RUNTIME_OPENSSLDIR` | `/usr/local/ssl` | Runtime OpenSSL/certificate directory for Linux, Android and Apple targets. Must be an absolute target POSIX path, not a host staging directory. |

Windows-hosted Android builds additionally require the following settings:

| Option | Default / requirement | Description |
| --- | --- | --- |
| `CC_OPENSSL_ANDROID_WINDOWS_HOST` | Explicit `ON` required | Enables the Windows/MSYS Android build route with a matching Windows NDK; does not invoke WSL. |
| `CC_OPENSSL_MSYS_ROOT` | Required; no default | Absolute path to an existing MSYS root containing `usr/bin/bash.exe`, `sh.exe`, `perl.exe` and `msys-2.0.dll`. |
| `CC_OPENSSL_PERL5LIB` | Empty (optional) | Absolute path to an existing directory of additional pure Perl modules for MSYS Perl. |

### Build configurations

Portable targets support single-configuration Debug/Release or
`CMAKE_CONFIGURATION_TYPES=Debug;Release` with Xcode/Ninja Multi-Config.
Set `CMAKE_TRY_COMPILE_CONFIGURATION` to match the configuration used for
consumer link probes. Build Apple architectures separately; universal/fat
library merging is not supported.

For tvOS, the adapter combines OpenSSL's Darwin target with the AppleTV Clang
target triple, SDK and deployment flag. This does not imply tvOS support in
other engine components.
