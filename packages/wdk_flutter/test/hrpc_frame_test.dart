import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wdk_flutter/wdk_flutter.dart';

/// Verifies the Dart HRPC **envelope** (`bare-rpc` framing) byte-for-byte
/// against the real `bare-rpc` encoder (vectors from
/// `tools/parity/oracle-frames.mjs`), plus an end-to-end request/response
/// round-trip through [HrpcWorkletRpc].
void main() {
  final List<dynamic> vectors =
      jsonDecode(
            File('test/fixtures/hrpc_frame_vectors.json').readAsStringSync(),
          )
          as List<dynamic>;

  group('HRPC frame parity vs bare-rpc', () {
    test('requests encode byte-for-byte', () {
      for (final dynamic v in vectors.where(
        (dynamic v) => v['kind'] == 'request',
      )) {
        final Uint8List frame = HrpcFrame.encodeRequest(
          id: v['id'] as int,
          command: v['command'] as int,
          body: _bytes(v['bodyHex'] as String),
        );
        expect(_hex(frame), v['frameHex'], reason: 'request ${v['method']}');
      }
    });

    test('success responses encode + decode correctly', () {
      final dynamic v = vectors.firstWhere(
        (dynamic v) => v['kind'] == 'response',
      );
      final Uint8List frame = HrpcFrame.encodeResponse(
        id: v['id'] as int,
        body: _bytes(v['bodyHex'] as String),
      );
      expect(_hex(frame), v['frameHex']);

      final HrpcMessage msg = HrpcFrame.decode(frame);
      expect(msg.type, HrpcFrame.typeResponse);
      expect(msg.id, v['id']);
      expect(_hex(msg.data!), v['bodyHex']);
    });

    test('error responses encode + decode to a mapped WdkError', () {
      final dynamic v = vectors.firstWhere((dynamic v) => v['kind'] == 'error');
      final Map<String, dynamic> e = v['error'] as Map<String, dynamic>;
      final Uint8List frame = HrpcFrame.encodeError(
        id: v['id'] as int,
        message: e['message'] as String,
        code: e['code'] as String,
        errno: e['errno'] as int,
      );
      expect(_hex(frame), v['frameHex']);

      final HrpcMessage msg = HrpcFrame.decode(frame);
      expect(msg.error, isNotNull);
      // "code:13,msg:cancelled" → friendly biometric message.
      expect(msg.error!.code, '13');
      expect(msg.error!.message, 'The biometric authentication was cancelled');
    });
  });

  group('HrpcWorkletRpc round-trip (loopback worklet)', () {
    test('correlates a reply and decodes the typed body', () async {
      final _LoopbackPipe pipe = _LoopbackPipe();
      pipe.onSend = (Uint8List requestFrame) {
        final HrpcMessage req = HrpcFrame.decode(requestFrame);
        // Reply as the worklet would: workletStart-response {status:'ok'}.
        final Uint8List body = SecretManagerMessages.encode(
          '@tetherto/wdk-secret-manager/command-workletStart-response',
          <String, Object?>{'status': 'ok'},
        );
        pipe.deliver(HrpcFrame.encodeResponse(id: req.id, body: body));
      };

      final HrpcWorkletRpc rpc = HrpcWorkletRpc(
        pipe,
        HrpcProtocol.secretManager(),
      );
      final Map<String, Object?> result = await rpc.call(
        'commandWorkletStart',
        <String, Object?>{'enableDebugLogs': 0},
      );
      expect(result['status'], 'ok');
      await rpc.close();
    });

    test('surfaces worklet error frames as WdkError', () async {
      final _LoopbackPipe pipe = _LoopbackPipe();
      pipe.onSend = (Uint8List requestFrame) {
        final HrpcMessage req = HrpcFrame.decode(requestFrame);
        pipe.deliver(
          HrpcFrame.encodeError(
            id: req.id,
            message: 'code:13,msg:cancelled',
            code: '13',
          ),
        );
      };

      final HrpcWorkletRpc rpc = HrpcWorkletRpc(
        pipe,
        HrpcProtocol.secretManager(),
      );
      await expectLater(
        rpc.call('commandDecrypt', <String, Object?>{
          'passkey': 'p',
          'salt': 's',
          'encryptedData': '00',
        }),
        throwsA(isA<WdkError>().having((WdkError e) => e.code, 'code', '13')),
      );
      await rpc.close();
    });
  });
}

class _LoopbackPipe implements IpcPipe {
  final StreamController<Uint8List> _ctrl = StreamController<Uint8List>();
  void Function(Uint8List frame)? onSend;

  void deliver(Uint8List bytes) => _ctrl.add(bytes);

  @override
  Stream<Uint8List> get inbound => _ctrl.stream;

  @override
  void send(Uint8List frame) => onSend?.call(frame);

  @override
  Future<void> close() => _ctrl.close();
}

String _hex(Uint8List b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _bytes(String hex) {
  final Uint8List out = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
