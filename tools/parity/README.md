# HRPC parity harness

WDK's worklet RPC is **HRPC** over **`compact-encoding`** (binary). To guarantee
the Dart codec matches Tether's exactly, we treat the real JS encoder as the
**oracle**: `oracle.mjs` runs the actual `@tetherto/wdk-react-native-provider`
secret-manager codecs and emits byte-exact vectors; the Dart test
(`packages/wdk_flutter/test/hrpc_parity_test.dart`) asserts our port reproduces
them.

## Regenerate the vectors

```bash
cd tools/parity
npm init -y && npm install hyperschema compact-encoding b4a
node oracle.mjs        # writes secret_manager_vectors.json
cp secret_manager_vectors.json ../../packages/wdk_flutter/test/fixtures/
```

`sm-messages.js` is the codec source copied verbatim from the published
provider (`lib/module/spec/hrpc/messages.js`).

## Status

- ✅ **secret-manager message codecs** — `compact-encoding` + all 5 messages
  (workletStart/Stop, generateAndEncrypt, decrypt, log), verified byte-exact.
- ⛔ **HRPC request/response envelope** — the framing the `hrpc/runtime` `RPC`
  class writes around each body (command id + request id + reply correlation).
  Capture full-frame vectors by driving the real `hrpc` over an in-memory
  duplex, then match in Dart.
- ⚠️ **manager (`@wdk-core`) methods — version-sensitive.** The provider
  (`beta.3`) calls named methods (`getAddress`, `sendTransaction`, …) while the
  packed `pear-wrk-wdk@beta.8` HRPC schema exposes a generic
  `@wdk-core/callMethod` + lifecycle ops. The manager method surface therefore
  depends on the exact paired `pear-wrk-wdk` version and must be pinned and
  re-vectored against the version the app ships. Do this before relying on the
  manager codecs.
