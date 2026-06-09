/// wdk_indexer — a typed Dart client for the WDK Indexer HTTP API.
///
/// Reproduces the two batch requests the React Native provider issues:
///   * `POST {url}/api/{version}/batch/token-balances`
///   * `POST {url}/api/{version}/batch/token-transfers`
/// both authenticated with an `x-api-key` header. `version` defaults to `v1`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Connection settings for the Indexer API.
@immutable
class IndexerConfig {
  const IndexerConfig({
    required this.apiKey,
    required this.url,
    this.version = 'v1',
  });

  final String apiKey;
  final String url;
  final String version;
}

/// A balance lookup for one (blockchain, token, address) triple.
@immutable
class BalanceQuery {
  const BalanceQuery({
    required this.blockchain,
    required this.token,
    required this.address,
  });
  final String blockchain;
  final String token;
  final String address;

  Map<String, Object?> toJson() => <String, Object?>{
    'blockchain': blockchain,
    'token': token,
    'address': address,
  };
}

/// A transfer-history lookup. [limit] defaults to 100, matching upstream.
@immutable
class TransferQuery {
  const TransferQuery({
    required this.blockchain,
    required this.token,
    required this.address,
    this.limit = 100,
    this.fromTs,
    this.toTs,
  });
  final String blockchain;
  final String token;
  final String address;
  final int limit;
  final int? fromTs;
  final int? toTs;

  Map<String, Object?> toJson() => <String, Object?>{
    'blockchain': blockchain,
    'token': token,
    'address': address,
    'limit': limit,
    if (fromTs != null) 'fromTs': fromTs,
    if (toTs != null) 'toTs': toTs,
  };
}

/// A token balance returned by the indexer.
@immutable
class TokenBalance {
  const TokenBalance({
    required this.amount,
    required this.blockchain,
    required this.token,
  });
  final double amount;
  final String blockchain;
  final String token;

  factory TokenBalance.fromJson(Map<String, Object?> json) => TokenBalance(
    amount: _toDouble(json['amount']),
    blockchain: (json['blockchain'] ?? '').toString(),
    token: (json['token'] ?? '').toString(),
  );
}

/// A token transfer returned by the indexer.
@immutable
class IndexerTransfer {
  const IndexerTransfer({
    required this.transactionHash,
    required this.blockchain,
    required this.token,
    required this.amount,
    required this.timestamp,
    this.from,
    this.to,
    this.blockNumber,
  });

  final String transactionHash;
  final String blockchain;
  final String token;
  final String amount;
  final int timestamp;
  final String? from;
  final String? to;
  final int? blockNumber;

  factory IndexerTransfer.fromJson(Map<String, Object?> json) =>
      IndexerTransfer(
        transactionHash: (json['transactionHash'] ?? '').toString(),
        blockchain: (json['blockchain'] ?? '').toString(),
        token: (json['token'] ?? '').toString(),
        amount: (json['amount'] ?? '0').toString(),
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        from: json['from']?.toString(),
        to: json['to']?.toString(),
        blockNumber: (json['blockNumber'] as num?)?.toInt(),
      );
}

/// Thrown on a non-200 indexer response.
class IndexerException implements Exception {
  IndexerException(this.endpoint, this.statusCode);
  final String endpoint;
  final int statusCode;
  @override
  String toString() => 'IndexerException($endpoint → $statusCode)';
}

/// Client for the WDK Indexer API.
class WdkIndexerClient {
  WdkIndexerClient(this.config, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final IndexerConfig config;
  final http.Client _http;

  Uri _endpoint(String path) =>
      Uri.parse('${config.url}/api/${config.version}/$path');

  Map<String, String> get _headers => <String, String>{
    'accept': 'application/json',
    'content-type': 'application/json',
    'x-api-key': config.apiKey,
  };

  /// Batch token balances. Returns a map keyed by `"{blockchain}_{token}"`,
  /// matching the key scheme used by the provider's balance map.
  Future<Map<String, TokenBalance>> batchTokenBalances(
    List<BalanceQuery> queries,
  ) async {
    if (queries.isEmpty) return <String, TokenBalance>{};
    final http.Response res = await _http.post(
      _endpoint('batch/token-balances'),
      headers: _headers,
      body: jsonEncode(queries.map((BalanceQuery q) => q.toJson()).toList()),
    );
    if (res.statusCode != 200) {
      throw IndexerException('batch/token-balances', res.statusCode);
    }
    final dynamic data = jsonDecode(res.body);
    final Map<String, TokenBalance> out = <String, TokenBalance>{};
    if (data is Map) {
      for (final Object? value in data.values) {
        if (value is Map && value['tokenBalance'] is Map) {
          final TokenBalance b = TokenBalance.fromJson(
            Map<String, Object?>.from(value['tokenBalance'] as Map),
          );
          out['${b.blockchain}_${b.token}'] = b;
        }
      }
    }
    return out;
  }

  /// Batch token transfers. The response array aligns by index with [queries];
  /// returns a map keyed by `"{blockchain}_{token}"`.
  Future<Map<String, List<IndexerTransfer>>> batchTokenTransfers(
    List<TransferQuery> queries,
  ) async {
    if (queries.isEmpty) return <String, List<IndexerTransfer>>{};
    final http.Response res = await _http.post(
      _endpoint('batch/token-transfers'),
      headers: _headers,
      body: jsonEncode(queries.map((TransferQuery q) => q.toJson()).toList()),
    );
    if (res.statusCode != 200) {
      throw IndexerException('batch/token-transfers', res.statusCode);
    }
    final dynamic data = jsonDecode(res.body);
    final Map<String, List<IndexerTransfer>> out =
        <String, List<IndexerTransfer>>{};
    if (data is List) {
      for (int i = 0; i < data.length && i < queries.length; i++) {
        final TransferQuery q = queries[i];
        final String key = '${q.blockchain}_${q.token}';
        final Object? item = data[i];
        final List<IndexerTransfer> transfers = <IndexerTransfer>[];
        if (item is Map && item['transfers'] is List) {
          for (final Object? t in item['transfers'] as List) {
            if (t is Map) {
              transfers.add(
                IndexerTransfer.fromJson(Map<String, Object?>.from(t)),
              );
            }
          }
        }
        out[key] = transfers;
      }
    }
    return out;
  }
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
