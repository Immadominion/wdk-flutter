import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wdk_indexer/wdk_indexer.dart';

const IndexerConfig _config = IndexerConfig(
  apiKey: 'test-key',
  url: 'https://wdk-api.tether.io',
);

void main() {
  group('batchTokenBalances', () {
    test('hits /api/v1/batch/token-balances with x-api-key and maps results', () async {
      final WdkIndexerClient client = WdkIndexerClient(
        _config,
        httpClient: MockClient((http.Request req) async {
          expect(req.method, 'POST');
          expect(req.url.path, '/api/v1/batch/token-balances');
          expect(req.headers['x-api-key'], 'test-key');
          expect(jsonDecode(req.body), <Object>[
            <String, Object?>{
              'blockchain': 'ethereum',
              'token': 'usdt',
              'address': '0xabc',
            },
          ]);
          return http.Response(
            jsonEncode(<String, Object?>{
              '0': <String, Object?>{
                'tokenBalance': <String, Object?>{
                  'amount': '12.5',
                  'blockchain': 'ethereum',
                  'token': 'usdt',
                },
              },
            }),
            200,
          );
        }),
      );

      final Map<String, TokenBalance> balances = await client.batchTokenBalances(
        const <BalanceQuery>[
          BalanceQuery(blockchain: 'ethereum', token: 'usdt', address: '0xabc'),
        ],
      );
      expect(balances.containsKey('ethereum_usdt'), isTrue);
      expect(balances['ethereum_usdt']!.amount, 12.5);
    });

    test('returns empty without an HTTP call for empty input', () async {
      bool called = false;
      final WdkIndexerClient client = WdkIndexerClient(
        _config,
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await client.batchTokenBalances(const <BalanceQuery>[]), isEmpty);
      expect(called, isFalse);
    });
  });

  group('batchTokenTransfers', () {
    test('aligns the response array with queries by index', () async {
      final WdkIndexerClient client = WdkIndexerClient(
        _config,
        httpClient: MockClient((http.Request req) async {
          expect(req.url.path, '/api/v1/batch/token-transfers');
          return http.Response(
            jsonEncode(<Object>[
              <String, Object?>{
                'transfers': <Object>[
                  <String, Object?>{
                    'transactionHash': '0xhash',
                    'blockchain': 'bitcoin',
                    'token': 'btc',
                    'amount': '100000',
                    'timestamp': 1700000000,
                    'from': 'a',
                    'to': 'b',
                  },
                ],
              },
            ]),
            200,
          );
        }),
      );

      final Map<String, List<IndexerTransfer>> txs =
          await client.batchTokenTransfers(
        const <TransferQuery>[
          TransferQuery(blockchain: 'bitcoin', token: 'btc', address: 'bc1q'),
        ],
      );
      expect(txs['bitcoin_btc']!.length, 1);
      expect(txs['bitcoin_btc']!.first.transactionHash, '0xhash');
      expect(txs['bitcoin_btc']!.first.amount, '100000');
    });
  });
}
