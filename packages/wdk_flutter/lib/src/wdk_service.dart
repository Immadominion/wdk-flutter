import 'wdk_core.dart';

/// The Flutter analog of the React Native `WDKService` facade.
///
/// It owns the lifecycle of the WDK Bare worklet (started via
/// `flutter_bare_kit`) and exposes the same imperative surface the RN starter
/// calls directly from its screens. All methods marshal to the worklet over
/// the IPC/bare-rpc channel; **no key material lives on the Flutter side.**
///
/// IMPLEMENTATION STATUS: facade + signatures are final; method bodies are
/// wired to the worklet RPC in milestone M2 once the protocol is extracted
/// from the shipped provider/worklet JS (see ROADMAP.md §4).
class WdkService {
  WdkService._();

  /// Process-wide singleton, matching the RN static `WDKService`.
  static final WdkService instance = WdkService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Boots the worklet and loads chain config. Call once at app launch.
  ///
  /// M2: start the worklet via `flutter_bare_kit`, load
  /// `wdk-worklet.mobile.bundle.js`, open the IPC/RPC channel, and pass
  /// [config] (indexer + chains + caching). For now this only flips the
  /// initialized flag so the app shell can render past its loading gate.
  Future<void> initialize(WdkConfig config) async {
    _initialized = true;
  }

  /// Generates a new 12-word BIP-39 mnemonic inside the worklet.
  ///
  /// [prf] is a per-device pseudo-random input (the RN starter sources it from
  /// the device unique id) used to bind the encrypted seed to the device.
  Future<String> createSeed({required String prf}) async => _todo('createSeed');

  /// Pre-calculates the fee for a send without broadcasting.
  Future<BigInt> quoteSendByNetwork({
    required NetworkType network,
    required int accountIndex,
    required BigInt amount,
    required String recipient,
    required AssetTicker asset,
  }) async =>
      _todo('quoteSendByNetwork');

  /// Builds, signs (in the worklet), and broadcasts a transaction.
  Future<SendResult> sendByNetwork({
    required NetworkType network,
    required int accountIndex,
    required BigInt amount,
    required String recipient,
    required AssetTicker asset,
  }) async =>
      _todo('sendByNetwork');

  /// Returns the integer denomination (decimals) for a token.
  int getDenominationValue(AssetTicker token) {
    switch (token) {
      case AssetTicker.btc:
        return 8;
      case AssetTicker.usdt:
      case AssetTicker.xaut:
        return 6;
    }
  }

  Never _todo(String method) => throw UnimplementedError(
        'WdkService.$method is wired to the worklet in milestone M2. '
        'See ROADMAP.md §4.',
      );
}
