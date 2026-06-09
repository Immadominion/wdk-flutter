import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;

/// Asset key for the WDK **manager** worklet bundle (the name referenced by the
/// RN starter's `types/wdk-bare.d.ts`). Update if your pinned package differs.
const String kWdkManagerBundleAsset =
    'assets/bundles/wdk-worklet.mobile.bundle.js';

/// Asset key for the **secret-manager** worklet bundle.
/// ⚠️ Confirm on-device — the filename/source is version-sensitive
/// (see `assets/bundles/README.md`).
const String kWdkSecretBundleAsset =
    'assets/bundles/wdk-secret-manager-worklet.bundle.js';

/// Loads the worklet bundles from app assets, ready to pass to
/// `WdkWorkletBinding.bind(...)` during native bring-up (Part B).
///
/// Throws a descriptive [StateError] if a bundle is missing — you add the
/// bundles per `assets/bundles/README.md`; they are intentionally not committed.
Future<({Uint8List manager, Uint8List secret})> loadWdkWorkletBundles({
  String managerAsset = kWdkManagerBundleAsset,
  String secretAsset = kWdkSecretBundleAsset,
}) async {
  return (manager: await _load(managerAsset), secret: await _load(secretAsset));
}

Future<Uint8List> _load(String key) async {
  try {
    final ByteData data = await rootBundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on Object catch (e) {
    throw StateError(
      'Missing worklet bundle asset "$key". Add it per assets/bundles/README.md '
      '(npm install @tetherto/pear-wrk-wdk@1.0.0-beta.4, copy bundle/*.js). '
      'Underlying error: $e',
    );
  }
}
