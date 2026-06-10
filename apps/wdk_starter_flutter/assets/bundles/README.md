# WDK worklet bundles

These JS bundles are the **unmodified** Tether WDK worklets that
`flutter_bare_kit` runs inside the Bare runtime. They are **not committed** (you
add them during native bring-up); this folder + its `pubspec.yaml` `assets:`
entry just reserve the slot.

## Get the bundles (pin the matched pair)

Both prebuilt mobile bundles ship **inside the provider package** (the RN
starter never references a bundle file directly — the provider loads them):

```bash
npm install @tetherto/wdk-react-native-provider@1.0.0-beta.3
ls node_modules/@tetherto/wdk-react-native-provider/lib/module/services/wdk-service/
#   wdk-worklet.mobile.bundle.js          (manager / @wdk-core worklet)
#   wdk-secret-manager-worklet.bundle.js  (secret-manager worklet)
```

> Pin **`provider@beta.3`** (which depends on `pear-wrk-wdk@beta.4`) — the exact
> pair the official RN starter uses. Later betas changed the manager API to a
> generic `callMethod`, which would break the byte-exact codecs. See
> `tools/parity/README.md`.

Copy both bundles here:

```bash
SRC=node_modules/@tetherto/wdk-react-native-provider/lib/module/services/wdk-service
cp "$SRC/wdk-worklet.mobile.bundle.js" \
   "$SRC/wdk-secret-manager-worklet.bundle.js" \
   apps/wdk_starter_flutter/assets/bundles/
```

The app loads them via `loadWdkWorkletBundles()` in `lib/wdk_bundles.dart`; the
asset keys there already match these filenames.
