import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wdk_pricing/wdk_pricing.dart';

void main() {
  group('BitfinexPricingClient', () {
    test('tickerFor uses the colon rule for symbols > 3 chars', () {
      final BitfinexPricingClient c = BitfinexPricingClient(
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      );
      expect(c.tickerFor('BTC', 'USD'), 'tBTCUSD');
      expect(c.tickerFor('XAUT', 'USD'), 'tXAUT:USD'); // 4 chars -> colon
      expect(c.tickerFor('usdt', 'usd'), 'tUSDT:USD'); // 4 chars -> colon
    });

    test('getCurrentPrice posts to /calc/fx and returns data[0]', () async {
      late http.Request captured;
      final BitfinexPricingClient c = BitfinexPricingClient(
        httpClient: MockClient((http.Request req) async {
          captured = req;
          expect(req.method, 'POST');
          expect(req.url.path, endsWith('/calc/fx'));
          expect(jsonDecode(req.body), <String, String>{
            'ccy1': 'BTC',
            'ccy2': 'USD',
          });
          return http.Response('[60000.5]', 200);
        }),
      );
      final double? price = await c.getCurrentPrice('btc', 'usd');
      expect(price, 60000.5);
      expect(captured.headers['content-type'], contains('application/json'));
    });

    test(
      'getMultiCurrentPrices parses last-price index 7 in input order',
      () async {
        final BitfinexPricingClient c = BitfinexPricingClient(
          httpClient: MockClient((http.Request req) async {
            expect(req.method, 'GET');
            expect(req.url.query, contains('tBTCUSD'));
            expect(req.url.query, contains('tXAUT:USD'));
            final List<List<Object>> body = <List<Object>>[
              <Object>['tBTCUSD', 0, 0, 0, 0, 100.0, 0.01, 60000.0, 0, 0, 0],
              <Object>['tXAUT:USD', 0, 0, 0, 0, 1.0, 0.001, 2400.0, 0, 0, 0],
            ];
            return http.Response(jsonEncode(body), 200);
          }),
        );
        final List<double?> prices = await c.getMultiCurrentPrices(
          const <PricePair>[PricePair('BTC', 'USD'), PricePair('XAUT', 'USD')],
        );
        expect(prices, <double>[60000.0, 2400.0]);
      },
    );
  });

  group('PricingProvider caching', () {
    test(
      'serves from cache within the duration, refetches after expiry',
      () async {
        int calls = 0;
        DateTime now = DateTime(2026, 6, 9, 12);
        final PricingProvider provider = PricingProvider(
          client: _CountingClient(() => (++calls) * 100.0),
          priceCacheDurationMs: 1000,
          now: () => now,
        );

        expect(await provider.getLastPrice('BTC', 'USD'), 100.0);
        // within cache window -> no new call
        now = now.add(const Duration(milliseconds: 500));
        expect(await provider.getLastPrice('BTC', 'USD'), 100.0);
        expect(calls, 1);
        // past cache window -> refetch
        now = now.add(const Duration(milliseconds: 600));
        expect(await provider.getLastPrice('BTC', 'USD'), 200.0);
        expect(calls, 2);
      },
    );

    test('forceRefresh bypasses the cache', () async {
      int calls = 0;
      final PricingProvider provider = PricingProvider(
        client: _CountingClient(() => (++calls) * 1.0),
      );
      await provider.getLastPrice('BTC', 'USD');
      await provider.getLastPrice('BTC', 'USD', forceRefresh: true);
      expect(calls, 2);
    });
  });
}

class _CountingClient implements PricingClient {
  _CountingClient(this._next);
  final double Function() _next;

  @override
  Future<double?> getCurrentPrice(String from, String to) async => _next();

  @override
  Future<List<double?>> getMultiCurrentPrices(List<PricePair> list) async =>
      list.map((_) => _next()).toList();
}
