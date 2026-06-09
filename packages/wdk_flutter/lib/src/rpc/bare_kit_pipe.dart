import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bare_kit/flutter_bare_kit.dart' as bare;

import 'secret_manager_rpc.dart';
import 'wdk_manager_rpc.dart';
import 'worklet_rpc.dart';

/// Adapts a `flutter_bare_kit` [bare.BareIPC] to the RPC layer's [IpcPipe].
/// This is the production transport once the native binding is built.
class BareKitIpcPipe implements IpcPipe {
  BareKitIpcPipe(this._ipc);
  final bare.BareIPC _ipc;

  @override
  Stream<Uint8List> get inbound => _ipc.stream;

  @override
  void send(Uint8List frame) => unawaited(_ipc.write(frame));

  @override
  Future<void> close() => _ipc.end();
}

/// Starts the two WDK worklets via `flutter_bare_kit` and returns the typed
/// RPC wrappers, ready to inject into [WdkService].
///
/// > ⚠️ The real worklet speaks **HRPC** (binary, compact-encoding). The
/// > default [rpcFactory] uses [JsonFrameWorkletRpc], which is the
/// > transport-agnostic reference codec — correct in *semantics* but not in
/// > *wire format*. To talk to the shipped worklet, pass an `rpcFactory` that
/// > builds an HRPC codec matching `spec/hrpc/hrpc.json`. Implementing +
/// > validating that codec on-device is the final M2 task (see
/// > NATIVE_INTEGRATION.md).
class WdkWorkletBinding {
  const WdkWorkletBinding._();

  static Future<({SecretManagerRpc secret, WdkManagerRpc manager})> bind({
    required Uint8List managerBundle,
    required Uint8List secretBundle,
    WorkletRpc Function(IpcPipe pipe)? rpcFactory,
  }) async {
    final WorkletRpc Function(IpcPipe) make =
        rpcFactory ?? (IpcPipe p) => JsonFrameWorkletRpc(p);

    final bare.Worklet secretW = await bare.Worklet.start(
      '/secret.manager.worklet.bundle',
      bundle: secretBundle,
    );
    final bare.Worklet managerW = await bare.Worklet.start(
      '/wdk.manager.worklet.bundle',
      bundle: managerBundle,
    );

    return (
      secret: SecretManagerRpc(make(BareKitIpcPipe(secretW.ipc))),
      manager: WdkManagerRpc(make(BareKitIpcPipe(managerW.ipc))),
    );
  }
}
