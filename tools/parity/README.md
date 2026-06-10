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
npm init -y && npm install hyperschema compact-encoding b4a hrpc bare-rpc
node oracle.mjs          # secret-manager bodies   -> secret_manager_vectors.json
node oracle-frames.mjs   # secret-manager frames    -> hrpc_frame_vectors.json
node oracle-mgr.mjs      # manager bodies + frames  -> wdk_manager_vectors.json
                         #                             wdk_manager_frame_vectors.json
cp secret_manager_vectors.json hrpc_frame_vectors.json \
   wdk_manager_vectors.json wdk_manager_frame_vectors.json \
   ../../packages/wdk_flutter/test/fixtures/
```

- `sm-messages.js` — the secret-manager codec source copied verbatim from the
  published provider (`lib/module/spec/hrpc/messages.js`).
- `wdk-core-messages.js` — the **manager** codec source copied verbatim from
  `@tetherto/pear-wrk-wdk@1.0.0-beta.4` (`spec/hrpc/messages.js`).

## Status

- ✅ **secret-manager message codecs** — `compact-encoding` + all 5 messages
  (workletStart/Stop, generateAndEncrypt, decrypt, log), verified byte-exact.
- ✅ **HRPC request/response envelope** — `bare-rpc` framing
  (`[uint32 frameLen][uint type][uint id][...][uint dataLen][data]`, errors as
  `utf8 message + utf8 code + int errno`). Ported in `hrpc_worklet_rpc.dart` and
  verified byte-exact against the real `bare-rpc` encoder via `oracle-frames.mjs`
  → `hrpc_frame_vectors.json` (requests, success response, error), plus a
  loopback request/response round-trip. The **secret-manager** worklet now
  speaks real HRPC end-to-end in `WdkWorkletBinding`.
- ✅ **manager (`@wdk-core`) message codecs** — all 15 commands (ids 0–14:
  `log`, `workletStart`, `getAddress(/Balance)`, `getAbstractedAddress(/Balance/
  TokenBalance)`, `quoteSendTransaction`, `sendTransaction`,
  `abstractedAccount{Transfer,QuoteTransfer}`, `abstractedSendTransaction`,
  `getApproveTransaction`, `getTransactionReceipt`, `dispose`), including the
  `c.frame` nested objects (`options`/`config`/`paymasterToken`) and the
  config-flag-after-options ordering. Ported in `wdk_manager_messages.dart`,
  verified byte-exact via `oracle-mgr.mjs` → `wdk_manager_vectors.json` (38
  bodies) + `wdk_manager_frame_vectors.json` (full frames). Wired as
  [HrpcProtocol.wdkManager]; the **manager** worklet now speaks real HRPC
  end-to-end in `WdkWorkletBinding`. `log`/`dispose` are send-only.

  > **Version pin (important):** these codecs are generated from
  > `@tetherto/pear-wrk-wdk@1.0.0-beta.4` — the version
  > `wdk-react-native-provider@beta.3` (the RN starter's pin) depends on. Later
  > betas (e.g. `beta.8`) changed the manager surface to a generic `callMethod`.
  > If the app ships a different `pear-wrk-wdk`, re-copy its `spec/hrpc/messages.js`
  > into `wdk-core-messages.js` and regenerate.
