/// wdk_flutter — the Flutter provider for Tether's Wallet Development Kit.
///
/// The Flutter analog of `@tetherto/wdk-react-native-provider`. It starts the
/// WDK Bare worklet via `flutter_bare_kit`, speaks the worklet's RPC protocol,
/// and exposes:
///   * [WdkService] — the imperative facade (`initialize`, `createSeed`,
///     `quoteSendByNetwork`, `sendByNetwork`, `getDenominationValue`).
///   * Riverpod providers reproducing the React Native `useWallet()` surface
///     ([walletProvider], [balancesProvider], [addressesProvider],
///     [transactionsProvider], and the granular state providers).
library;

export 'src/wdk_core.dart';
export 'src/wdk_providers.dart';
export 'src/wdk_service.dart';
