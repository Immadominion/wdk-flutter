import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../wdk_core.dart';

/// Request/response RPC to a WDK worklet.
///
/// The *semantics* — method names, params, and result shapes — are faithful to
/// the worklet's HRPC interface. The *wire encoding* lives in the concrete
/// transport: in production a binary HRPC codec over `flutter_bare_kit`'s IPC;
/// [JsonFrameWorkletRpc] below is a transport-agnostic reference implementation
/// (newline-delimited JSON) used in dev and tests.
abstract class WorkletRpc {
  /// Calls [method] with [params] and completes with the result object, or
  /// throws a [WdkError] if the worklet returns an error.
  Future<Map<String, Object?>> call(String method, Map<String, Object?> params);

  Future<void> close();
}

/// A bidirectional byte pipe to a worklet (the IPC channel).
///
/// The production implementation wraps `flutter_bare_kit`'s `BareIPC`
/// ([inbound] ← `IPC.stream`, [send] → `IPC.write`).
abstract class IpcPipe {
  Stream<Uint8List> get inbound;
  void send(Uint8List frame);
  Future<void> close();
}

/// A [WorkletRpc] that frames calls as newline-delimited JSON envelopes over an
/// [IpcPipe] and correlates responses by an incrementing request id.
///
/// Envelope out: `{"id": n, "method": "...", "params": {...}}`
/// Envelope in:  `{"id": n, "result": {...}}` or `{"id": n, "error": "..."}`
class JsonFrameWorkletRpc implements WorkletRpc {
  JsonFrameWorkletRpc(
    this._pipe, {
    this.requestTimeout = const Duration(seconds: 30),
  }) {
    _sub = _pipe.inbound.listen(_onBytes);
  }

  final IpcPipe _pipe;
  final Duration requestTimeout;

  late final StreamSubscription<Uint8List> _sub;
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  final List<int> _buffer = <int>[];
  int _nextId = 1;
  bool _closed = false;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params,
  ) {
    if (_closed) {
      throw StateError('WorkletRpc is closed');
    }
    final int id = _nextId++;
    final Completer<Map<String, Object?>> completer =
        Completer<Map<String, Object?>>();
    _pending[id] = completer;

    final String frame = jsonEncode(<String, Object?>{
      'id': id,
      'method': method,
      'params': params,
    });
    _pipe.send(Uint8List.fromList(utf8.encode('$frame\n')));

    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw WdkError(code: 'timeout', message: 'RPC "$method" timed out');
      },
    );
  }

  void _onBytes(Uint8List bytes) {
    _buffer.addAll(bytes);
    int newline;
    while ((newline = _buffer.indexOf(0x0a)) != -1) {
      final List<int> line = _buffer.sublist(0, newline);
      _buffer.removeRange(0, newline + 1);
      if (line.isEmpty) continue;
      _dispatch(utf8.decode(line));
    }
  }

  void _dispatch(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map) return;
    final Object? rawId = decoded['id'];
    if (rawId is! int) return;
    final Completer<Map<String, Object?>>? completer = _pending.remove(rawId);
    if (completer == null || completer.isCompleted) return;

    if (decoded.containsKey('error') && decoded['error'] != null) {
      final WdkError err = WdkError.parse(decoded['error'].toString()) ??
          WdkError(code: 'rpc', message: decoded['error'].toString());
      completer.completeError(err);
      return;
    }
    final Object? result = decoded['result'];
    completer.complete(
      result is Map ? Map<String, Object?>.from(result) : <String, Object?>{},
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _sub.cancel();
    for (final Completer<Map<String, Object?>> c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('WorkletRpc closed'));
      }
    }
    _pending.clear();
    await _pipe.close();
  }
}
