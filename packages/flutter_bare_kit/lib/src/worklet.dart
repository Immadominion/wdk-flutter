import 'dart:async';

import 'package:flutter/services.dart';

/// Method channel shared by all worklets.
const MethodChannel _methods =
    MethodChannel('dev.web3flutter.flutter_bare_kit/methods');

/// A handle to a single Bare worklet (an isolated Bare thread) and the IPC
/// pipe used to talk to it.
///
/// Mirrors `react-native-bare-kit`'s `Worklet`/`IPC` surface. The Dart side is
/// a thin platform-channel bridge; the native side (Android/iOS) embeds the
/// Bare runtime via Holepunch's `bare-kit` and forwards bytes over the IPC
/// pipe. See `NATIVE_INTEGRATION.md`.
class Worklet {
  Worklet._(this.id, this.ipc);

  /// Native handle id for this worklet instance.
  final int id;

  /// The bidirectional pipe to the worklet.
  final BareIPC ipc;

  /// Starts a worklet from a Bare [bundle] (`bare-pack` output) or raw [source].
  ///
  /// [filename] is the logical entry name reported to the worklet. Returns once
  /// the native side has created the worklet and its IPC pipe.
  static Future<Worklet> start(
    String filename, {
    Uint8List? bundle,
    String? source,
    List<String> args = const <String>[],
    int? memoryLimitBytes,
  }) async {
    assert(bundle != null || source != null,
        'Provide either a bundle or source');
    final Object? raw = await _methods
        .invokeMethod<Object?>('startWorklet', <String, Object?>{
      'filename': filename,
      'source': ?source,
      'bundle': ?bundle,
      'args': args,
      'memoryLimit': ?memoryLimitBytes,
    });
    final int id = (raw as num).toInt();
    return Worklet._(id, BareIPC._(id));
  }

  Future<void> suspend() =>
      _methods.invokeMethod<void>('suspend', <String, Object?>{'id': id});

  Future<void> resume() =>
      _methods.invokeMethod<void>('resume', <String, Object?>{'id': id});

  Future<void> terminate() =>
      _methods.invokeMethod<void>('terminate', <String, Object?>{'id': id});
}

/// The IPC duplex between the Flutter host and a [Worklet].
///
/// Inbound frames arrive on an [EventChannel] keyed by the worklet id; outbound
/// frames are written via the method channel. Framing/serialization is the
/// caller's responsibility (the WDK provider layers HRPC on top).
class BareIPC {
  BareIPC._(this._id)
      : _events =
            EventChannel('dev.web3flutter.flutter_bare_kit/ipc/$_id');

  final int _id;
  final EventChannel _events;

  /// Inbound frames from the worklet.
  Stream<Uint8List> get stream => _events
      .receiveBroadcastStream()
      .map((Object? e) => e is Uint8List ? e : Uint8List.fromList(<int>[]));

  /// Writes an outbound frame to the worklet.
  Future<void> write(Uint8List data) => _methods.invokeMethod<void>(
        'ipcWrite',
        <String, Object?>{'id': _id, 'data': data},
      );

  /// Closes the host side of the pipe.
  Future<void> end() =>
      _methods.invokeMethod<void>('ipcEnd', <String, Object?>{'id': _id});
}
