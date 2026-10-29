# G3 security review of 03f095e9f82 (#846) and 664efdd6843 (#847)

A `security` subagent reviewed both commits, read-only, with probes in a clone reset to f7ae03d4ca6. It found **no security findings.**

**#846 (this issue)**
- `PerformanceInterceptor` never reads `options.uri`, `realUri` or `queryParameters`, so values passed through `queryParameters:` never reach a trace.
- The template's trace name is built from the redacted path and cut at `?`. Its `http_path` is redacted again, which is idempotent.
- **Regression found, filed as koniz-dev/flutter-starter#851 (P2):** `redactPath` throws on a malformed percent-encoded query key. #846 runs it on every request, so such a request now fails in every build. Previously it failed only with HTTP logging on. It fails closed; no leak.
- **Residual, filed as koniz-dev/flutter-starter#853 (docs):** a token in a path segment is not redacted. That matches the documented "by key name" rule, which #846 did not change.

**#847 (koniz-dev/flutter-starter#796)**
- Every connection is pinned: `connect()` is the only place a channel opens, and each call takes a fresh pinned client.
- `IOWebSocketChannel.connect` passes `customClient` to `WebSocket.connect`. The loopback TLS test passes 10/10.
- `ws://` with pinning on has no TLS to pin, the same as `ApiClient` over `http://`; the docs claim refusal only for `wss://`.
- When misconfigured: debug asserts out of `connect` before any state changes; release falls back to unpinned, consistent with `ApiClient`.
- Web: `createHttpClient()` returns null there. A probe entrypoint using the client builds with `flutter build web` and with `--wasm`.
- **Older than both commits, filed as koniz-dev/flutter-starter#852:** the WebSocket URL, query token included, appears in debug log lines and in the cancellation exception.
