# flutter_bare_kit — Native Integration (Milestone M2)

This package embeds **Holepunch's Bare runtime** so a Flutter app can run a
Bare *worklet* — in this project, Tether's unmodified
`@tetherto/pear-wrk-wdk` WDK worklet — and exchange bytes with it over IPC.

## Status

| Layer | State |
|---|---|
| Dart API (`Worklet`, `BareIPC`) | ✅ Done — platform-channel bridge, analyze-clean |
| `BareKitIpcPipe` + `WdkWorkletBinding` (in `wdk_flutter`) | ✅ Done — adapts IPC → RPC |
| Android native (Bare embed) | ⛔ Scaffolded — needs `bare-kit` + NDK build **on your machine** |
| iOS native (Bare embed) | ⛔ Scaffolded — needs the BareKit pod/xcframework **on your machine** |
| HRPC binary codec | ⛔ Open — the worklet speaks HRPC, not the dev JSON codec |

The app runs today in **preview mode** (UI + validation work; signing throws a
clear "needs worklet (M2)" message). Completing the steps below flips it to a
fully functional wallet.

## The channel contract (what native must implement)

The Dart side (`lib/src/worklet.dart`) talks to native over:

- **Method channel** `dev.web3flutter.flutter_bare_kit/methods`:
  - `startWorklet({filename, source?|bundle?, args, memoryLimit?}) → int id`
  - `ipcWrite({id, data: Uint8List})`, `ipcEnd({id})`
  - `suspend({id})`, `resume({id})`, `terminate({id})`
- **Event channel** `dev.web3flutter.flutter_bare_kit/ipc/<id>`: streams inbound
  `Uint8List` frames from worklet → Dart.

The Kotlin/Swift plugins already register these channels and answer
`getPlatformVersion`; the worklet cases currently return `bare_kit_unwired`.

## Android

1. Vendor Bare's native sources the way `react-native-bare-kit` does — it uses
   `cmake-fetch` to pull `bare`/`bare-kit` and links via `bare-link`. Add a
   `CMakeLists.txt` under `android/` and wire it through `externalNativeBuild`
   in `android/build.gradle` (NDK).
2. Add the `bare-kit` Java API (`to.holepunch.bare.kit.Worklet` / `IPC`).
3. In `FlutterBareKitPlugin.kt`, implement the worklet cases:
   - `startWorklet`: allocate an id, `Worklet().start(filename, source/bundle, args)`,
     create an `IPC`, register a `FlutterEventChannel`
     `dev.web3flutter.flutter_bare_kit/ipc/<id>`, and pump `IPC` reads into its sink.
   - `ipcWrite`: `IPC.write(bytes)`; `terminate`: `Worklet.terminate()`.

## iOS

1. In `flutter_bare_kit.podspec`, depend on **BareKit** (the pod / `.xcframework`
   that `react-native-bare-kit` ships under `apple/`). Add
   `s.dependency 'BareKit'` (or `s.vendored_frameworks`).
2. In `FlutterBareKitPlugin.swift`, implement the worklet cases with
   `BareWorklet` + `BareIPC` and a `FlutterEventChannel` per worklet id.

## Bundle the worklet assets

The worklet bundles are produced by `bare-pack` (the RN provider's
`gen:worker-bundle` script packs `@tetherto/pear-wrk-wdk/src/wdk-worklet.js`).
You can reuse the prebuilt `wdk-worklet.mobile.bundle.js` +
`wdk-secret-manager-worklet.bundle.js` shipped in
`@tetherto/wdk-react-native-provider`. Add them as Flutter assets, load the
bytes, and pass them to `WdkWorkletBinding.bind(managerBundle:, secretBundle:)`.

## HRPC codec (the last correctness step)

`JsonFrameWorkletRpc` is a transport-agnostic reference codec — correct in
*semantics*, wrong in *wire format*. The real worklet uses **HRPC** (binary,
compact-encoding) defined by `spec/hrpc/hrpc.json` in the RN provider. Implement
an `HrpcWorkletRpc implements WorkletRpc` that encodes/decodes per that schema,
then pass it as `WdkWorkletBinding.bind(rpcFactory: (pipe) => HrpcWorkletRpc(pipe))`.

## Flip the app from preview → bound

Override the service provider once the binding works:

```text
final binding = await WdkWorkletBinding.bind(
  managerBundle: <bytes>, secretBundle: <bytes>,
  rpcFactory: (pipe) => HrpcWorkletRpc(pipe),
);
// wdkServiceProvider -> WdkService(secretManager: binding.secret, wdkManager: binding.manager, ...)
```

## Verify parity

With the binding live, assert the **same mnemonic produces the same addresses**
as the React Native starter for BTC + EVM (it must — it's the same worklet),
then run a testnet send end-to-end.
