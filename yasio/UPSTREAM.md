# yasio

- Repository: https://github.com/simdsoft/yasio
- Release: **v4.4.1** (GitHub latest stable release checked 2026-11-07)
- Commit: `a7c8428fec7aaccf20b0ee8cc6cdc88aad5d4d3b`
- Contents: upstream `yasio/`, `LICENSE`, and `BSL_1_0.txt`, copied without source changes.

The local `CMakeLists.txt` builds `io_service.cpp` and `xxsocket.cpp` as a static library. It propagates C++20 and `YASIO_SSL_BACKEND=1`, and links the project's OpenSSL target. Header-only mode is not enabled. No dependency download is needed at configure time.

The cocos Lua timer adapter lives in `cocos/scripting/lua-bindings/manual/yasio_cclua.*`. HTTP and WebSocket apply the engine's certificate and hostname verification policy through `network/SSLVerification.h`; the raw upstream yasio API retains its own TLS policy.
