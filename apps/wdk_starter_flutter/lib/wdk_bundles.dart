import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;

/// Asset key for the WDK **manager** worklet bundle. This is the prebuilt
/// mobile bundle shipped in `@tetherto/wdk-react-native-provider@beta.3` at
/// `lib/module/services/wdk-service/wdk-worklet.mobile.bundle.js`.
const String kWdkManagerBundleAsset =
    'assets/bundles/wdk-worklet.mobile.bundle.js';

/// Asset key for the **secret-manager** worklet bundle, shipped alongside the
/// manager bundle in the same provider directory
/// (`wdk-secret-manager-worklet.bundle.js`).
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
      '(npm install @tetherto/wdk-react-native-provider@1.0.0-beta.3, copy '
      'node_modules/@tetherto/wdk-react-native-provider/lib/module/services/'
      'wdk-service/*.bundle.js). Underlying error: $e',
    );
  }
}
