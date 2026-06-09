/// flutter_bare_kit — a Flutter binding for Holepunch's Bare runtime.
///
/// It embeds the Bare native libraries (the same native layer that
/// `react-native-bare-kit` vendors and builds via `cmake-fetch`/`bare-link`)
/// so a Flutter app can start an isolated Bare thread — a "worklet" — and
/// exchange bytes with it over an IPC pipe.
///
/// In this project it is used to run Tether's **unmodified**
/// `@tetherto/pear-wrk-wdk` worklet bundle, which performs all seed/key
/// custody and signing off the UI thread.
library;

import 'flutter_bare_kit_platform_interface.dart';

export 'src/worklet.dart';

/// Entry point for plugin-level calls that are not tied to a specific worklet.
class FlutterBareKit {
  /// Returns the host platform version (smoke-test that the plugin is wired).
  Future<String?> getPlatformVersion() {
    return FlutterBareKitPlatform.instance.getPlatformVersion();
  }
}
