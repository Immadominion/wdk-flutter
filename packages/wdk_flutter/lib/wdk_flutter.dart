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

export 'src/address_validation.dart';
export 'src/rpc/bare_kit_pipe.dart';
export 'src/rpc/compact_encoding.dart';
export 'src/rpc/hrpc_secret_messages.dart';
export 'src/rpc/secret_manager_rpc.dart';
export 'src/rpc/wdk_manager_rpc.dart';
export 'src/rpc/worklet_rpc.dart';
export 'src/secret/secret_storage.dart';
export 'src/secret/wdk_encryption_salt.dart';
export 'src/wdk_constants.dart';
export 'src/wdk_core.dart';
export 'src/wdk_providers.dart';
export 'src/wdk_service.dart';
