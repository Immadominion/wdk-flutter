import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wdk_flutter/wdk_flutter.dart';
import 'package:wdk_indexer/wdk_indexer.dart';

void main() {
  group('JsonFrameWorkletRpc (id correlation over an IPC pipe)', () {
    test('correlates concurrent responses by id and echoes params', () async {
      final JsonFrameWorkletRpc rpc = JsonFrameWorkletRpc(
        LoopbackPipe(
          (String method, Map<String, Object?> params) => <String, Object?>{
            'method': method,
            'echo': params['n'],
          },
        ),
      );
      final List<Map<String, Object?>> results = await Future.wait(
        <Future<Map<String, Object?>>>[
          rpc.call('a', <String, Object?>{'n': 1}),
          rpc.call('b', <String, Object?>{'n': 2}),
          rpc.call('c', <String, Object?>{'n': 3}),
        ],
      );
      expect(results[0]['echo'], 1);
      expect(results[1]['echo'], 2);
      expect(results[2]['echo'], 3);
      await rpc.close();
    });

    test('surfaces a worklet error frame as a WdkError', () async {
      final JsonFrameWorkletRpc rpc = JsonFrameWorkletRpc(
        LoopbackPipe((_, _) => throw const WdkError(code: '5', message: 'bad')),
      );
      await expectLater(
        rpc.call('x', const <String, Object?>{}),
        throwsA(isA<WdkError>().having((WdkError e) => e.code, 'code', '5')),
      );
      await rpc.close();
    });
  });

  group('WdkService preview mode (no worklet binding)', () {
    test(
      'quote/send throw WorkletUnavailable until the M2 binding lands',
      () async {
        final WdkService svc = WdkService(storage: InMemorySecretStorage());
        await expectLater(
          svc.quoteSendByNetwork(
            network: NetworkType.ethereum,
            accountIndex: 0,
            amount: 1,
            recipient: '0xabc',
            asset: AssetTicker.usdt,
          ),
          throwsA(isA<WorkletUnavailable>()),
        );
      },
    );
  });

  group('WdkService.createSeed', () {
    test('encrypts, persists, and derives a 12-word mnemonic', () async {
      final WdkService svc = WdkService(
        storage: InMemorySecretStorage(),
        secretManager: SecretManagerRpc(
          FakeWorkletRpc(<String, Responder>{
            'commandWorkletStart': (_) => <String, Object?>{
              'status': 'started',
            },
            'commandGenerateAndEncrypt': (_) => <String, Object?>{
              'encryptedEntropy': 'aa',
              'encryptedSeed': 'bb',
            },
            'commandDecrypt': (_) => <String, Object?>{
              'result': '00000000000000000000000000000000',
            },
          }),
        ),
      );

      final String mnemonic = await svc.createSeed(prf: 'device-123');
      expect(mnemonic.split(' ').length, 12);
      expect(mnemonic.split(' ').first, 'abandon'); // all-zero entropy
    });
  });

  group('WdkService quote/send routing', () {
    WdkService managerService(FakeWorkletRpc rpc) => WdkService(
      wdkManager: WdkManagerRpc(rpc),
      storage: InMemorySecretStorage(),
    );

    test('SegWit quote divides the fee by 1e8', () async {
      final WdkService svc = managerService(
        FakeWorkletRpc(<String, Responder>{
          'quoteSendTransaction': (_) => <String, Object?>{'fee': '5000'},
        }),
      );
      final double fee = await svc.quoteSendByNetwork(
        network: NetworkType.segwit,
        accountIndex: 0,
        amount: 0.01,
        recipient: 'bc1qxyz',
        asset: AssetTicker.btc,
      );
      expect(fee, 5000 / 100000000);
    });

    test('EVM quote uses abstracted transfer and divides by 1e6', () async {
      final WdkService svc = managerService(
        FakeWorkletRpc(<String, Responder>{
          'abstractedAccountQuoteTransfer': (_) => <String, Object?>{
            'fee': '3000',
          },
        }),
      );
      final double fee = await svc.quoteSendByNetwork(
        network: NetworkType.ethereum,
        accountIndex: 0,
        amount: 5,
        recipient: '0xabc',
        asset: AssetTicker.usdt,
      );
      expect(fee, 3000 / 1000000);
    });

    test('EVM send returns the broadcast hash', () async {
      final WdkService svc = managerService(
        FakeWorkletRpc(<String, Responder>{
          'abstractedAccountTransfer': (_) => <String, Object?>{
            'hash': '0xdeadbeef',
            'fee': '20',
          },
        }),
      );
      final SendResult r = await svc.sendByNetwork(
        network: NetworkType.ethereum,
        accountIndex: 0,
        amount: 5,
        recipient: '0xabc',
        asset: AssetTicker.usdt,
      );
      expect(r.hash, '0xdeadbeef');
    });
  });

  group('WdkService.resolveWalletBalances (indexer wiring)', () {
    test('maps indexer balances to typed WalletBalance entries', () async {
      final WdkService svc = WdkService(
        storage: InMemorySecretStorage(),
        indexerFactory: (IndexerConfig c) => WdkIndexerClient(
          c,
          httpClient: MockClient((http.Request req) async {
            return http.Response(
              jsonEncode(<String, Object?>{
                '0': <String, Object?>{
                  'tokenBalance': <String, Object?>{
                    'amount': '5.5',
                    'blockchain': 'ethereum',
                    'token': 'usdt',
                  },
                },
              }),
              200,
            );
          }),
        ),
      );
      svc.setConfig(
        const WdkConfig(
          indexer: IndexerConfig(apiKey: 'k', url: 'https://x'),
          chains: <String, Object?>{},
        ),
      );

      final List<WalletBalance> balances = await svc.resolveWalletBalances(
        <AssetTicker>[AssetTicker.usdt],
        <NetworkType, String>{NetworkType.ethereum: '0xabc'},
      );
      expect(balances.length, 1);
      expect(balances.first.asset, AssetTicker.usdt);
      expect(balances.first.network, NetworkType.ethereum);
      expect(balances.first.amount, 5.5);
    });
  });
}

typedef Responder = Map<String, Object?> Function(Map<String, Object?> params);

/// A [WorkletRpc] whose responses come from a method→handler map.
class FakeWorkletRpc implements WorkletRpc {
  FakeWorkletRpc(this.handlers);
  final Map<String, Responder> handlers;
  final List<String> calls = <String>[];

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params,
  ) async {
    calls.add(method);
    final Responder? h = handlers[method];
    if (h == null) {
      throw WdkError(code: 'nomethod', message: 'no handler: $method');
    }
    return h(params);
  }

  @override
  Future<void> close() async {}
}

/// An [IpcPipe] that synchronously answers each sent frame via [responder].
class LoopbackPipe implements IpcPipe {
  LoopbackPipe(this.responder);
  final Map<String, Object?> Function(
    String method,
    Map<String, Object?> params,
  )
  responder;
  final StreamController<Uint8List> _ctrl =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get inbound => _ctrl.stream;

  @override
  void send(Uint8List frame) {
    final Map<String, Object?> req =
        (jsonDecode(utf8.decode(frame).trim()) as Map<String, dynamic>)
            .cast<String, Object?>();
    final Object? id = req['id'];
    try {
      final Map<String, Object?> result = responder(
        req['method'] as String,
        (req['params'] as Map<String, dynamic>).cast<String, Object?>(),
      );
      _emit(<String, Object?>{'id': id, 'result': result});
    } catch (e) {
      final String err = e is WdkError ? e.serialize() : e.toString();
      _emit(<String, Object?>{'id': id, 'error': err});
    }
  }

  void _emit(Map<String, Object?> frame) =>
      _ctrl.add(Uint8List.fromList(utf8.encode('${jsonEncode(frame)}\n')));

  @override
  Future<void> close() async => _ctrl.close();
}
