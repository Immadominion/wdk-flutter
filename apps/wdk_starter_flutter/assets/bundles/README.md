# WDK worklet bundles

These JS bundles are the **unmodified** Tether WDK worklets that
`flutter_bare_kit` runs inside the Bare runtime. They are **not committed** (you
add them during native bring-up); this folder + its `pubspec.yaml` `assets:`
entry just reserve the slot.

## Get the bundles (pin the matched pair)

```bash
npm install @tetherto/pear-wrk-wdk@1.0.0-beta.4
ls node_modules/@tetherto/pear-wrk-wdk/bundle/
```

> Pin **`beta.4`** (the version the official RN starter uses with
> `wdk-react-native-provider@beta.3`). Later betas dropped the prebuilt
> `bundle/` and changed the manager API — see `tools/parity/README.md`.

Copy the prebuilt bundle(s) here, e.g.:

```bash
cp node_modules/@tetherto/pear-wrk-wdk/bundle/wdk-worklet.mobile.bundle.js \
   apps/wdk_starter_flutter/assets/bundles/
```

The app loads them via `loadWdkWorkletBundles()` in `lib/wdk_bundles.dart`.

> ⚠️ **Confirm the exact filenames on-device.** The manager worklet is
> `wdk-worklet.mobile.bundle.js` (referenced by the RN starter's
> `types/wdk-bare.d.ts`). The **secret-manager** worklet's bundle name/source
> can differ by version — verify what's actually in `bundle/` (and/or the
> provider package) and update the asset keys in `lib/wdk_bundles.dart` to match.
