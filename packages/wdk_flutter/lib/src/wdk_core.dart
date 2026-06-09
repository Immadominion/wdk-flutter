import 'package:meta/meta.dart';
import 'package:wdk_indexer/wdk_indexer.dart' show IndexerConfig;

export 'package:wdk_indexer/wdk_indexer.dart' show IndexerConfig;

/// Blockchain networks WDK exposes. Mirrors the React Native provider's
/// `NetworkType`, plus `plasma` (named in the Template Wallet bounty).
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

/// Thrown when a wallet operation needs the worklet but the native
/// `flutter_bare_kit` binding is not yet wired (milestone M2).
class WorkletUnavailable implements Exception {
  const WorkletUnavailable([this.detail = '']);
  final String detail;
  @override
  String toString() =>
      'WorkletUnavailable: the WDK worklet binding is not wired yet (M2). $detail';
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

/// A balance for an asset on a network, in whole token units.
@immutable
class WalletBalance {
  const WalletBalance({
    required this.asset,
    required this.network,
    required this.amount,
  });

  final AssetTicker asset;
  final NetworkType network;
  final double amount;
}

/// A transaction as reported by the Indexer (amount is the raw on-chain value).
@immutable
class TransactionRecord {
  const TransactionRecord({
    required this.transactionHash,
    required this.network,
    required this.asset,
    required this.amount,
    required this.timestamp,
    this.from,
    this.to,
  });

  final String transactionHash;
  final NetworkType network;
  final AssetTicker asset;
  final String amount;
  final DateTime timestamp;
  final String? from;
  final String? to;
}

/// Result of a successful send: the broadcast hash and (when available) fee.
@immutable
class SendResult {
  const SendResult({required this.hash, this.fee});

  final String hash;
  final String? fee;
}
