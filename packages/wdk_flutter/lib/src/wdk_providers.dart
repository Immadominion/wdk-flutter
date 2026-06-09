import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wdk_core.dart';
import 'wdk_service.dart';

/// The active [WdkConfig]. Override this at the app root via `ProviderScope`,
/// mirroring the RN `<WalletProvider config={...}>` prop.
final Provider<WdkConfig> wdkConfigProvider = Provider<WdkConfig>(
  (Ref ref) => throw UnimplementedError(
    'Override wdkConfigProvider in ProviderScope at the app root.',
  ),
);

/// The process-wide [WdkService] facade.
final Provider<WdkService> wdkServiceProvider =
    Provider<WdkService>((Ref ref) => WdkService.instance);

/// Snapshot of wallet state — the Flutter analog of the fields returned by the
/// React Native `useWallet()` hook.
class WalletState {
  const WalletState({
    this.wallet,
    this.isInitialized = false,
    this.isUnlocked = false,
    this.isLoading = false,
  });

  final WalletInfo? wallet;
  final bool isInitialized;
  final bool isUnlocked;
  final bool isLoading;

  WalletState copyWith({
    WalletInfo? wallet,
    bool? isInitialized,
    bool? isUnlocked,
    bool? isLoading,
    bool clearWallet = false,
  }) {
    return WalletState(
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      isInitialized: isInitialized ?? this.isInitialized,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Owns wallet state and the imperative operations. Mirrors the methods the RN
/// `useWallet()` hook exposes: `createWallet`, `unlockWallet`,
/// `refreshWalletBalance`, `clearWallet`.
class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() => const WalletState();

  WdkService get _service => ref.read(wdkServiceProvider);

  /// Marks the engine as initialized once [WdkService.initialize] has run.
  void markInitialized() =>
      state = state.copyWith(isInitialized: _service.isInitialized);

  /// Creates (or, with [mnemonic], imports) a wallet.
  Future<void> createWallet({required String name, String? mnemonic}) async {
    state = state.copyWith(isLoading: true);
    // M2: call the worklet to create/import, then load identity + balances.
    state = state.copyWith(isLoading: false, isUnlocked: true);
  }

  /// Triggers biometric unlock. Returns whether the wallet is now unlocked.
  Future<bool> unlockWallet() async {
    // M2: local_auth + worklet unlock.
    state = state.copyWith(isUnlocked: true);
    return state.isUnlocked;
  }

  /// Refreshes balances and transactions from the Indexer.
  Future<void> refreshWalletBalance() async {
    // M2: re-fetch via wdk_indexer (respecting enableCaching).
  }

  /// Deletes the wallet and its keys from the device.
  Future<void> clearWallet() async {
    // M2: wipe keystore + worklet state.
    state = state.copyWith(clearWallet: true, isUnlocked: false);
  }
}

/// The wallet state notifier — the primary `useWallet()` analog.
final NotifierProvider<WalletNotifier, WalletState> walletProvider =
    NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);

// Granular derived providers so widgets rebuild only on what they read,
// mirroring the destructured fields of `useWallet()`.

final Provider<WalletInfo?> walletInfoProvider =
    Provider<WalletInfo?>((Ref ref) => ref.watch(walletProvider).wallet);

final Provider<bool> isInitializedProvider =
    Provider<bool>((Ref ref) => ref.watch(walletProvider).isInitialized);

final Provider<bool> isUnlockedProvider =
    Provider<bool>((Ref ref) => ref.watch(walletProvider).isUnlocked);

final Provider<bool> walletLoadingProvider =
    Provider<bool>((Ref ref) => ref.watch(walletProvider).isLoading);

/// Current balances. M2: backed by an Indexer-fetching AsyncNotifier.
final Provider<List<WalletBalance>> balancesProvider =
    Provider<List<WalletBalance>>((Ref ref) => const <WalletBalance>[]);

/// Receive addresses per network. M2: populated from the worklet.
final Provider<Map<NetworkType, String>> addressesProvider =
    Provider<Map<NetworkType, String>>(
  (Ref ref) => const <NetworkType, String>{},
);

/// Transaction history. M2: backed by an Indexer-fetching AsyncNotifier.
final Provider<List<TransactionRecord>> transactionsProvider =
    Provider<List<TransactionRecord>>((Ref ref) => const <TransactionRecord>[]);
