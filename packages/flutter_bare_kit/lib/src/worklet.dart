import 'dart:async';
import 'dart:typed_data';

/// A handle to a single Bare worklet (an isolated Bare thread) and the IPC
/// pipe used to talk to it.
///
/// Mirrors `react-native-bare-kit`'s `Worklet`/`IPC` surface so that the
/// message protocol used by the WDK provider ports across unchanged:
///
/// 1. [start] boots the worklet from a bundled `.bundle.js` (e.g. Tether's
///    `wdk-worklet.mobile.bundle.js`, loaded as a Flutter asset).
/// 2. The host writes request frames via [BareIPC.write] and reads response
///    frames from [BareIPC.stream]. A higher-level RPC (bare-rpc style) is
///    layered on top in the `wdk_flutter` provider.
///
/// IMPLEMENTATION STATUS: API stub. The native layer (Android CMake/NDK build
/// of `bare-kit`, iOS podspec building the `apple/` sources, bridged to Dart
/// via platform channels or FFI) is the keystone task of milestone M2.
class Worklet {
  /// Wraps an [ipc] pipe to an already-started worklet. Prefer [start].
  Worklet(this.ipc);

  /// The bidirectional pipe to the worklet.
  final BareIPC ipc;

  /// Starts a worklet.
  ///
  /// [filename] is the logical entry name reported to the worklet; [bundle] is
  /// the bytes of a Bare bundle (`bare-pack` output). [source] may be provided
  /// instead of [bundle] to run raw JS. [args] are passed to the worklet.
  static Future<Worklet> start(
    String filename, {
    Uint8List? bundle,
    String? source,
    List<String> args = const <String>[],
    int? memoryLimitBytes,
  }) {
    throw UnimplementedError(
      'flutter_bare_kit native layer not yet implemented (milestone M2). '
      'See ROADMAP.md §3.1.',
    );
  }

  /// Suspends the worklet's event loop (e.g. when the app backgrounds).
  Future<void> suspend() => throw UnimplementedError();

  /// Resumes a suspended worklet.
  Future<void> resume() => throw UnimplementedError();

  /// Terminates the worklet and releases native resources.
  Future<void> terminate() => throw UnimplementedError();
}

/// The IPC duplex between the Flutter host and a [Worklet].
///
/// Non-blocking in both directions, matching Bare's IPC semantics. Frames are
/// raw bytes; framing/serialization is the caller's responsibility (the WDK
/// provider uses the same framing as the React Native provider).
class BareIPC {
  /// Inbound frames from the worklet.
  Stream<Uint8List> get stream =>
      throw UnimplementedError('flutter_bare_kit native layer pending (M2).');

  /// Writes an outbound frame to the worklet.
  Future<void> write(Uint8List data) =>
      throw UnimplementedError('flutter_bare_kit native layer pending (M2).');

  /// Closes the host side of the pipe.
  Future<void> end() => throw UnimplementedError();
}
