import 'dart:async';
import 'dart:typed_data';

import '../wdk_core.dart';
import 'compact_encoding.dart';
import 'hrpc_secret_messages.dart';
import 'worklet_rpc.dart';

/// HRPC = `bare-rpc` framing over `compact-encoding`. Every message is:
///
/// ```
/// [uint32 LE frameLen][uint type][uint id][...type header...][uint dataLen][data]
/// ```
///
/// `type`: REQUEST=1, RESPONSE=2, STREAM=3. `id` correlates a reply to its
/// request (events use id 0). Errors travel in a RESPONSE as
/// `utf8 message + utf8 code + int errno`. This is the exact wire format the
/// WDK worklets speak; it is verified byte-for-byte against the real `bare-rpc`
/// encoder (see `tools/parity/oracle-frames.mjs` →
/// `test/fixtures/hrpc_frame_vectors.json`).
class HrpcFrame {
  const HrpcFrame._();

  static const int typeRequest = 1;
  static const int typeResponse = 2;
  static const int typeStream = 3;

  /// Encodes a non-streaming REQUEST frame carrying [body] (the
  /// compact-encoding message body) for [command] with correlation [id].
  static Uint8List encodeRequest({
    required int id,
    required int command,
    required Uint8List body,
  }) {
    final CompactEncoder header = CompactEncoder()
      ..uint(typeRequest)
      ..uint(id)
      ..uint(command)
      ..uint(0) // stream == 0 (non-streaming) → data follows
      ..uint(body.length);
    final Uint8List headerBytes = header.takeBytes();

    final CompactEncoder frameLen = CompactEncoder()
      ..uint32(headerBytes.length + body.length);
    final BytesBuilder out = BytesBuilder()
      ..add(frameLen.takeBytes())
      ..add(headerBytes)
      ..add(body);
    return out.toBytes();
  }

  /// Encodes a non-streaming RESPONSE frame carrying [body]. (The host never
  /// sends these to the worklet; provided for tests and host-side mocking.)
  static Uint8List encodeResponse({required int id, required Uint8List body}) {
    final CompactEncoder header = CompactEncoder()
      ..uint(typeResponse)
      ..uint(id)
      ..boolean(false)
      ..uint(0)
      ..uint(body.length);
    final Uint8List headerBytes = header.takeBytes();
    final CompactEncoder frameLen = CompactEncoder()
      ..uint32(headerBytes.length + body.length);
    return (BytesBuilder()
          ..add(frameLen.takeBytes())
          ..add(headerBytes)
          ..add(body))
        .toBytes();
  }

  /// Encodes an error RESPONSE frame (`utf8 message + utf8 code + int errno`).
  static Uint8List encodeError({
    required int id,
    required String message,
    String code = '',
    int errno = 0,
  }) {
    final CompactEncoder header = CompactEncoder()
      ..uint(typeResponse)
      ..uint(id)
      ..boolean(true)
      ..uint(0)
      ..string(message)
      ..string(code)
      ..intZigzag(errno);
    final Uint8List headerBytes = header.takeBytes();
    final CompactEncoder frameLen = CompactEncoder()
      ..uint32(headerBytes.length);
    return (BytesBuilder()
          ..add(frameLen.takeBytes())
          ..add(headerBytes))
        .toBytes();
  }

  /// Decodes one complete frame buffer into an [HrpcMessage].
  static HrpcMessage decode(Uint8List frame) {
    final CompactDecoder d = CompactDecoder(frame);
    d.uint32(); // frame length (already used for slicing)
    final int type = d.uint();
    final int id = d.uint();

    if (type == typeRequest) {
      final int command = d.uint();
      final int stream = d.uint();
      final Uint8List? data = stream == 0 ? d.readBuffer() : null;
      return HrpcMessage(type: type, id: id, command: command, data: data);
    }

    if (type == typeResponse) {
      final bool isError = d.boolean();
      final int stream = d.uint();
      if (isError) {
        final String message = d.string(); // utf8
        final String code = d.string(); // utf8
        d.intZigzag(); // errno (unused)
        final WdkError err =
            WdkError.parse(message) ??
            WdkError(code: code.isNotEmpty ? code : 'rpc', message: message);
        return HrpcMessage(type: type, id: id, error: err);
      }
      final Uint8List? data = stream == 0 ? d.readBuffer() : null;
      return HrpcMessage(type: type, id: id, data: data);
    }

    // STREAM frames are not used by the non-streaming WDK commands.
    return HrpcMessage(type: type, id: id);
  }
}

/// A decoded HRPC message (the envelope, not the typed body).
class HrpcMessage {
  const HrpcMessage({
    required this.type,
    required this.id,
    this.command,
    this.error,
    this.data,
  });

  final int type;
  final int id;
  final int? command;
  final WdkError? error;
  final Uint8List? data;
}

/// Maps a high-level method name to its HRPC command id and body codecs.
class HrpcMethod {
  const HrpcMethod(this.command, this.encodeRequest, this.decodeResponse);
  final int command;
  final Uint8List Function(Map<String, Object?>) encodeRequest;
  final Map<String, Object?> Function(Uint8List) decodeResponse;
}

/// The method table for one worklet's HRPC interface.
class HrpcProtocol {
  const HrpcProtocol(this.methods);
  final Map<String, HrpcMethod> methods;

  static const String _sm = '@tetherto/wdk-secret-manager';

  /// The `wdkSecretManager` worklet protocol (command ids per its
  /// `spec/hrpc/hrpc.json`: workletStart=0, workletStop=1,
  /// generateAndEncrypt=2, decrypt=3). Body codecs are byte-exact ports of the
  /// provider's `messages.js` (see [SecretManagerMessages]).
  factory HrpcProtocol.secretManager() {
    return HrpcProtocol(<String, HrpcMethod>{
      'commandWorkletStart': HrpcMethod(
        0,
        (Map<String, Object?> m) => SecretManagerMessages.encode(
          '$_sm/command-workletStart-request',
          m,
        ),
        (Uint8List b) => SecretManagerMessages.decode(
          '$_sm/command-workletStart-response',
          b,
        ),
      ),
      'commandWorkletStop': HrpcMethod(
        1,
        (Map<String, Object?> m) =>
            SecretManagerMessages.encode('$_sm/command-workletStop-request', m),
        (Uint8List b) => SecretManagerMessages.decode(
          '$_sm/command-workletStop-response',
          b,
        ),
      ),
      'commandGenerateAndEncrypt': HrpcMethod(
        2,
        (Map<String, Object?> m) => SecretManagerMessages.encode(
          '$_sm/command-generateAndEncrypt-request',
          m,
        ),
        (Uint8List b) => SecretManagerMessages.decode(
          '$_sm/command-generateAndEncrypt-response',
          b,
        ),
      ),
      'commandDecrypt': HrpcMethod(
        3,
        (Map<String, Object?> m) =>
            SecretManagerMessages.encode('$_sm/command-decrypt-request', m),
        (Uint8List b) =>
            SecretManagerMessages.decode('$_sm/command-decrypt-response', b),
      ),
    });
  }
}

/// A [WorkletRpc] that speaks real HRPC (`bare-rpc` framing) to a worklet over
/// an [IpcPipe], correlating replies by request id.
///
/// Currently provided with the verified [HrpcProtocol.secretManager] table; the
/// manager (`@wdk-core`) table is version-sensitive and added once the pinned
/// `pear-wrk-wdk` body codecs are ported (see `tools/parity/README.md`).
class HrpcWorkletRpc implements WorkletRpc {
  HrpcWorkletRpc(
    this._pipe,
    this._protocol, {
    this.requestTimeout = const Duration(seconds: 30),
  }) {
    _sub = _pipe.inbound.listen(_onBytes);
  }

  final IpcPipe _pipe;
  final HrpcProtocol _protocol;
  final Duration requestTimeout;

  late final StreamSubscription<Uint8List> _sub;
  final Map<
    int,
    ({Completer<Map<String, Object?>> completer, HrpcMethod method})
  >
  _pending =
      <int, ({Completer<Map<String, Object?>> completer, HrpcMethod method})>{};
  final BytesBuilder _inbox = BytesBuilder();
  int _nextId = 1;
  bool _closed = false;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params,
  ) {
    if (_closed) throw StateError('HrpcWorkletRpc is closed');
    final HrpcMethod? spec = _protocol.methods[method];
    if (spec == null) {
      throw ArgumentError('No HRPC mapping for method "$method"');
    }
    final int id = _nextId++;
    final Uint8List body = spec.encodeRequest(params);
    final Completer<Map<String, Object?>> completer =
        Completer<Map<String, Object?>>();
    _pending[id] = (completer: completer, method: spec);
    _pipe.send(
      HrpcFrame.encodeRequest(id: id, command: spec.command, body: body),
    );
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw WdkError(code: 'timeout', message: 'HRPC "$method" timed out');
      },
    );
  }

  void _onBytes(Uint8List bytes) {
    _inbox.add(bytes);
    Uint8List buf = _inbox.toBytes();
    int consumed = 0;
    while (buf.length - consumed >= 4) {
      final int frameLen = _u32le(buf, consumed);
      final int total = 4 + frameLen;
      if (buf.length - consumed < total) break;
      _handleFrame(Uint8List.sublistView(buf, consumed, consumed + total));
      consumed += total;
    }
    _inbox.clear();
    if (consumed < buf.length) _inbox.add(buf.sublist(consumed));
  }

  void _handleFrame(Uint8List frame) {
    final HrpcMessage msg = HrpcFrame.decode(frame);
    if (msg.type != HrpcFrame.typeResponse) return; // worklet → host replies
    final pending = _pending.remove(msg.id);
    if (pending == null || pending.completer.isCompleted) return;
    if (msg.error != null) {
      pending.completer.completeError(msg.error!);
      return;
    }
    pending.completer.complete(
      pending.method.decodeResponse(msg.data ?? Uint8List(0)),
    );
  }

  static int _u32le(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  @override
  Future<void> close() async {
    _closed = true;
    await _sub.cancel();
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(StateError('HrpcWorkletRpc closed'));
      }
    }
    _pending.clear();
    await _pipe.close();
  }
}
