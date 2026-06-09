import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bare_kit/flutter_bare_kit.dart' as bare;

import 'hrpc_worklet_rpc.dart';
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
/// Wire format: the real worklets speak **HRPC** (`bare-rpc` framing over
/// `compact-encoding`). The **secret-manager** worklet uses [HrpcWorkletRpc]
/// with [HrpcProtocol.secretManager] — a byte-exact port verified against the
/// real encoder (`tools/parity/`). The **manager** (`@wdk-core`) worklet still
/// uses [JsonFrameWorkletRpc] (semantically faithful, not yet wire-faithful):
/// its body codecs are version-sensitive and are ported once the pinned
/// `pear-wrk-wdk` (beta.4) is available on-device (see `tools/parity/README.md`).
///
/// Pass [rpcFactory] to override both transports (used by tests/preview).
class WdkWorkletBinding {
  const WdkWorkletBinding._();

  static Future<({SecretManagerRpc secret, WdkManagerRpc manager})> bind({
    required Uint8List managerBundle,
    required Uint8List secretBundle,
    WorkletRpc Function(IpcPipe pipe)? rpcFactory,
  }) async {
    final WorkletRpc Function(IpcPipe) secretMake =
        rpcFactory ??
        (IpcPipe p) => HrpcWorkletRpc(p, HrpcProtocol.secretManager());
    final WorkletRpc Function(IpcPipe) managerMake =
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
      secret: SecretManagerRpc(secretMake(BareKitIpcPipe(secretW.ipc))),
      manager: WdkManagerRpc(managerMake(BareKitIpcPipe(managerW.ipc))),
    );
  }
}
