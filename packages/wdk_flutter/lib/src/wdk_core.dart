import 'package:meta/meta.dart';

/// Blockchain networks WDK exposes. Mirrors the React Native provider's
/// `NetworkType`, plus `plasma` (in scope per the Template Wallet bounty).
enum NetworkType {
  ethereum('ethereum'),
  polygon('polygon'),
  arbitrum('arbitrum'),
  plasma('plasma'),
  ton('ton'),
  tron('tron'),
  solana('solana'),
  segwit('bitcoin'),
  lightning('lightning');

  const NetworkType(this.id);

  /// The on-the-wire identifier used by the WDK worklet/config.
  final String id;

  static NetworkType fromId(String id) =>
      values.firstWhere((NetworkType n) => n.id == id);
}

/// Assets supported by the template. Mirrors the RN provider's `AssetTicker`.
enum AssetTicker {
  btc('btc'),
  usdt('usdt'),
  xaut('xaut');

  const AssetTicker(this.id);

  final String id;

  static AssetTicker fromId(String id) =>
      values.firstWhere((AssetTicker a) => a.id == id);
}

/// Fiat currencies for price conversion.
enum FiatCurrency { usd }

/// An error surfaced by the WDK worklet.
///
/// The worklet serializes errors as the string `"code:X,msg:Y"`; [parse]
/// reproduces the React Native starter's decoding (see
/// `wdk-starter-react-native/src/utils/parse-worklet-error.ts`), including the
/// friendly message for code `13` (biometric authentication cancelled).
@immutable
class WdkError implements Exception {
  const WdkError({required this.code, required this.message});

  final String code;
  final String message;

  static const Map<String, String> _friendly = <String, String>{
    '13': 'The biometric authentication was cancelled',
  };

  /// Decodes a `"code:X,msg:Y"` worklet error string, or returns `null` if the
  /// input is not in that shape.
  static WdkError? parse(String? raw) {
    if (raw == null) return null;
    final List<String> parts = raw.split(',');
    if (parts.length < 2) return null;
    final String codeRaw = parts[0].trim();
    final String msgRaw = parts[1].trim();
    if (!codeRaw.startsWith('code:') || !msgRaw.startsWith('msg:')) return null;
    final String code = codeRaw.substring('code:'.length).trim();
    final String message = msgRaw.substring('msg:'.length).trim();
    return WdkError(code: code, message: _friendly[code] ?? message);
  }

  /// Re-encodes to the `"code:X,msg:Y"` wire form.
  String serialize() => 'code:$code,msg:$message';

  @override
  String toString() => 'WdkError(code: $code, message: $message)';
}

/// Connection settings for the WDK Indexer HTTP API.
@immutable
class IndexerConfig {
  const IndexerConfig({required this.apiKey, required this.url});

  final String apiKey;
  final String url;
}

/// Top-level WDK configuration, supplied at app root. Mirrors the RN
/// `<WalletProvider config={{ indexer, chains, enableCaching }}>` prop.
///
/// [chains] is intentionally an untyped map so the React Native chains config
/// (`get-chains-config.ts`) can be reused verbatim without re-modelling it.
@immutable
class WdkConfig {
  const WdkConfig({
    required this.indexer,
    required this.chains,
    this.enableCaching = true,
  });

  final IndexerConfig indexer;
  final Map<String, Object?> chains;
  final bool enableCaching;
}

/// Identity of a wallet held on the device.
@immutable
class WalletInfo {
  const WalletInfo({
    required this.id,
    required this.name,
    this.enabledAssets = const <AssetTicker>[],
  });

  final String id;
  final String name;
  final List<AssetTicker> enabledAssets;
}

/// A single balance entry for an asset on a network.
@immutable
class WalletBalance {
  const WalletBalance({
    required this.networkType,
    required this.denomination,
    required this.value,
  });

  final NetworkType networkType;
  final String denomination;
  final BigInt value;
}

/// A transaction as reported by the Indexer.
@immutable
class TransactionRecord {
  const TransactionRecord({
    required this.transactionHash,
    required this.blockchain,
    required this.amount,
    required this.token,
    required this.timestamp,
    this.from,
    this.to,
  });

  final String transactionHash;
  final NetworkType blockchain;
  final BigInt amount;
  final AssetTicker token;
  final DateTime timestamp;
  final String? from;
  final String? to;
}

/// Result of a successful send: the broadcast hash and the fee paid.
@immutable
class SendResult {
  const SendResult({required this.hash, required this.fee});

  final String hash;
  final BigInt fee;
}
