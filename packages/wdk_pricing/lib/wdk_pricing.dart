/// wdk_pricing — a Dart port of `@tetherto/wdk-pricing-provider` and
/// `@tetherto/wdk-pricing-bitfinex-http`.
///
/// [PricingProvider] caches last prices for a configurable duration;
/// [BitfinexPricingClient] talks to Bitfinex's public v2 API. Behavior mirrors
/// the upstream JS: `/calc/fx` for a single conversion, `/tickers` for batches,
/// and the `tXAUT:USD` colon rule when a symbol exceeds three characters.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A currency pair, e.g. `from: 'BTC', to: 'USD'`.
@immutable
class PricePair {
  const PricePair(this.from, this.to);
  final String from;
  final String to;
}

/// Interface a pricing source must implement (mirrors upstream `PricingClient`).
abstract class PricingClient {
  /// Current price of [from] in [to], or null if the pair can't be resolved.
  Future<double?> getCurrentPrice(String from, String to);

  /// Current prices for many pairs, in input order (nulls for unresolved).
  Future<List<double?>> getMultiCurrentPrices(List<PricePair> list);
}

/// Bitfinex public-API client. Mirrors `BitfinexPricingClient`.
class BitfinexPricingClient implements PricingClient {
  BitfinexPricingClient({http.Client? httpClient, Uri? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? Uri.parse('https://api-pub.bitfinex.com/v2');

  final http.Client _http;
  final Uri _baseUrl;

  static const int _lastPriceIndex = 7;

  /// Bitfinex requires a colon when either symbol is longer than 3 chars
  /// (e.g. `tXAUT:USD` rather than `tXAUTUSD`).
  @visibleForTesting
  String tickerFor(String from, String to) {
    final String f = from.toUpperCase();
    final String t = to.toUpperCase();
    if (f.length > 3 || t.length > 3) return 't$f:$t';
    return 't$f$t';
  }

  @override
  Future<double?> getCurrentPrice(String from, String to) async {
    final http.Response res = await _http.post(
      _baseUrl.resolve('calc/fx'),
      headers: const <String, String>{
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'ccy1': from.toUpperCase(),
        'ccy2': to.toUpperCase(),
      }),
    );
    if (res.statusCode != 200) {
      throw HttpPricingException('Bitfinex /calc/fx', res.statusCode, res.body);
    }
    final dynamic data = jsonDecode(res.body);
    if (data is List && data.isNotEmpty && data.first is num) {
      return (data.first as num).toDouble();
    }
    return null;
  }

  @override
  Future<List<double?>> getMultiCurrentPrices(List<PricePair> list) async {
    if (list.isEmpty) return const <double?>[];
    final String symbols = list
        .map((PricePair p) => tickerFor(p.from, p.to))
        .join(',');
    final http.Response res = await _http.get(
      _baseUrl.resolve('tickers?symbols=$symbols'),
    );
    if (res.statusCode != 200) {
      throw HttpPricingException('Bitfinex /tickers', res.statusCode, res.body);
    }
    final dynamic data = jsonDecode(res.body);
    final Map<String, double> bySymbol = <String, double>{};
    if (data is List) {
      for (final dynamic row in data) {
        if (row is List && row.length > _lastPriceIndex) {
          final Object? sym = row[0];
          final Object? last = row[_lastPriceIndex];
          if (sym is String && last is num) bySymbol[sym] = last.toDouble();
        }
      }
    }
    return list
        .map((PricePair p) => bySymbol[tickerFor(p.from, p.to)])
        .toList();
  }
}

/// Thrown when Bitfinex returns a non-200 response.
class HttpPricingException implements Exception {
  HttpPricingException(this.endpoint, this.statusCode, this.body);
  final String endpoint;
  final int statusCode;
  final String body;
  @override
  String toString() => 'HttpPricingException($endpoint → $statusCode)';
}

/// Cache-aware pricing provider. Mirrors `PricingProvider`.
class PricingProvider {
  PricingProvider({
    required this.client,
    this.priceCacheDurationMs = 60 * 60 * 1000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PricingClient client;
  final int priceCacheDurationMs;
  final DateTime Function() _now;

  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  String _key(String from, String to) =>
      '${from.toUpperCase()}${to.toUpperCase()}';

  /// Returns the last price of [from] in [to], cached for
  /// [priceCacheDurationMs]. Pass [forceRefresh] to bypass the cache.
  Future<double> getLastPrice(
    String from,
    String to, {
    bool forceRefresh = false,
  }) async {
    final int nowMs = _now().millisecondsSinceEpoch;
    final String key = _key(from, to);
    final _CacheEntry? cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        nowMs - cached.timestampMs < priceCacheDurationMs) {
      return cached.value;
    }
    final double? price = await client.getCurrentPrice(from, to);
    if (price == null) {
      throw StateError('Could not resolve price for $from/$to');
    }
    _cache[key] = _CacheEntry(price, nowMs);
    return price;
  }

  /// Batched [getLastPrice] for many pairs (each independently cached).
  Future<List<double>> getMultiLastPrices(
    List<PricePair> list, {
    bool forceRefresh = false,
  }) {
    return Future.wait(
      list.map(
        (PricePair p) => getLastPrice(p.from, p.to, forceRefresh: forceRefresh),
      ),
    );
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.timestampMs);
  final double value;
  final int timestampMs;
}
