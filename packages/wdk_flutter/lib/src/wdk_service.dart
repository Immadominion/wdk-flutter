import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart' as conv;
import 'package:wdk_indexer/wdk_indexer.dart';

import 'rpc/secret_manager_rpc.dart';
import 'rpc/wdk_manager_rpc.dart';
import 'secret/secret_storage.dart';
import 'secret/wdk_encryption_salt.dart';
import 'wdk_constants.dart';
import 'wdk_core.dart';

/// Faithful Dart port of the React Native `WDKService`.
///
/// Orchestrates the two worklets (secret manager + wdk manager) over their RPC
/// wrappers, persists encrypted secrets in [SecretStorage], and reads balances
/// and transactions from the WDK Indexer. Dependencies are injected so the
/// routing/derivation/indexer logic is unit-testable with fakes.
///
/// When the worklet RPCs are absent (the native `flutter_bare_kit` binding is
/// not wired yet — milestone M2), the service runs in **preview mode**:
/// [initialize] succeeds so the UI can render, but seed/wallet/transfer
/// operations throw [WorkletUnavailable] with a clear message.
class WdkService {
  WdkService({
    SecretManagerRpc? secretManager,
    WdkManagerRpc? wdkManager,
    SecretStorage? storage,
    WdkIndexerClient Function(IndexerConfig config)? indexerFactory,
    int Function()? clockMs,
  }) : _secret = secretManager,
       _manager = wdkManager,
       _storage = storage ?? FlutterSecureStorageSecretStorage(),
       _indexerFactory =
           indexerFactory ?? ((IndexerConfig c) => WdkIndexerClient(c)),
       _clockMs = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SecretManagerRpc? _secret;
  final WdkManagerRpc? _manager;
  final SecretStorage _storage;
  final WdkIndexerClient Function(IndexerConfig) _indexerFactory;
  final int Function() _clockMs;

  WdkConfig? _config;
  WdkIndexerClient? _indexer;
  bool _initialized = false;

  /// Default assets a new wallet enables (matches the RN provider).
  static const List<AssetTicker> defaultAssets = <AssetTicker>[
    AssetTicker.btc,
    AssetTicker.usdt,
    AssetTicker.xaut,
  ];

  bool get isInitialized => _initialized;

  /// Whether the worklet RPC layer is bound (false until the M2 native binding).
  bool get isWorkletBound => _secret != null && _manager != null;

  void setConfig(WdkConfig config) {
    _config = config;
    _indexer = _indexerFactory(config.indexer);
  }

  WdkConfig get _requireConfig =>
      _config ?? (throw StateError('WDK Service config not set'));

  SecretManagerRpc get _requireSecret =>
      _secret ?? (throw const WorkletUnavailable('secret manager'));

  WdkManagerRpc get _requireManager =>
      _manager ?? (throw const WorkletUnavailable('wdk manager'));

  /// Boots the service. In preview mode (no worklet binding) it just marks
  /// initialized so the UI can render.
  Future<void> initialize(WdkConfig config) async {
    if (_initialized) return;
    setConfig(config);
    _initialized = true;
  }

  // --- Secret manager flow -------------------------------------------------

  /// Generates a new 12-word mnemonic, encrypting + persisting the secret.
  Future<String> createSeed({required String prf}) async {
    return _generateAndStore(prf: prf);
  }

  /// Imports an existing mnemonic, encrypting + persisting it.
  Future<bool> importSeedPhrase({
    required String prf,
    required String seedPhrase,
  }) async {
    await _generateAndStore(prf: prf, seedPhrase: seedPhrase);
    return true;
  }

  Future<String> _generateAndStore({
    required String prf,
    String? seedPhrase,
  }) async {
    final SecretManagerRpc secret = _requireSecret;
    final String saltHex = conv.hex.encode(generateWdkSalt(prf));

    final String status = await secret.commandWorkletStart();
    if (status != 'started') {
      throw const WdkError(
        code: 'worklet',
        message: 'Error while starting the worklet.',
      );
    }

    final EncryptedSecret enc = await secret.commandGenerateAndEncrypt(
      passkey: prf,
      saltHex: saltHex,
      seedPhrase: seedPhrase,
    );
    await _storage.write(SecretKey.entropy, enc.encryptedEntropy);
    await _storage.write(SecretKey.seed, enc.encryptedSeed);
    await _storage.write(SecretKey.salt, saltHex);

    final String entropyHex = await secret.commandDecrypt(
      passkey: prf,
      saltHex: saltHex,
      encryptedDataHex: enc.encryptedEntropy,
    );
    return bip39.entropyToMnemonic(entropyHex);
  }

  /// Returns the stored mnemonic for [prf], or null if none is stored.
  Future<String?> retrieveSeed(String prf) async {
    final bool hasAll =
        await _storage.contains(SecretKey.entropy) &&
        await _storage.contains(SecretKey.seed) &&
        await _storage.contains(SecretKey.salt);
    if (!hasAll) return null;

    final SecretManagerRpc secret = _requireSecret;
    final String? encryptedEntropy = await _storage.read(SecretKey.entropy);
    final String? saltHex = await _storage.read(SecretKey.salt);
    if (encryptedEntropy == null || saltHex == null) return null;

    final String status = await secret.commandWorkletStart();
    if (status != 'started') {
      throw const WdkError(
        code: 'worklet',
        message: 'Error while starting the worklet.',
      );
    }
    final String entropyHex = await secret.commandDecrypt(
      passkey: prf,
      saltHex: saltHex,
      encryptedDataHex: encryptedEntropy,
    );
    return bip39.entropyToMnemonic(entropyHex);
  }

  // --- Wallet lifecycle ----------------------------------------------------

  Future<WalletInfo> createWallet({
    required String walletName,
    required String prf,
  }) async {
    final WdkManagerRpc manager = _requireManager;
    final String seed = await retrieveSeed(prf) ?? await createSeed(prf: prf);

    final WalletInfo wallet = WalletInfo(
      id: 'wallet_${_clockMs()}',
      name: walletName,
      enabledAssets: defaultAssets,
    );

    await manager.workletStart(
      seedPhrase: seed,
      configJson: jsonEncode(_requireConfig.chains),
    );
    return wallet;
  }

  Future<void> clearWallet() async {
    try {
      await _manager?.workletStop();
    } catch (_) {
      /* worklet may not be running */
    }
    try {
      await _secret?.commandWorkletStop();
    } catch (_) {
      /* worklet may not be running */
    }
    await _storage.deleteAll();
  }

  // --- Addresses -----------------------------------------------------------

  Future<String> getAssetAddress(NetworkType network, int index) async {
    final WdkManagerRpc manager = _requireManager;
    if (network == NetworkType.segwit) {
      return manager.getAddress(network: network.id, accountIndex: index);
    }
    return manager.getAbstractedAddress(
      network: network.id,
      accountIndex: index,
    );
  }

  /// Resolves a network→address map for the enabled assets. Mirrors the RN
  /// behavior of mapping Polygon/Arbitrum to the Ethereum (abstracted) address.
  Future<Map<NetworkType, String>> resolveWalletAddresses(
    List<AssetTicker> enabledAssets, {
    int index = 0,
  }) async {
    final Map<NetworkType, String> out = <NetworkType, String>{};
    final Set<NetworkType> networks = <NetworkType>{};
    for (final AssetTicker asset in enabledAssets) {
      networks.addAll(assetNetworks[asset] ?? const <NetworkType>[]);
    }
    for (final NetworkType network in networks) {
      try {
        out[network] = await getAssetAddress(network, index);
      } catch (_) {
        // leave unresolved networks out of the map
      }
    }
    if (out.containsKey(NetworkType.ethereum)) {
      out[NetworkType.polygon] = out[NetworkType.ethereum]!;
      out[NetworkType.arbitrum] = out[NetworkType.ethereum]!;
    }
    return out;
  }

  // --- Quote / send --------------------------------------------------------

  int getDenominationValue(AssetTicker asset) => denominationFor(asset).toInt();

  /// Fee estimate (in whole token units) for sending [amount] of [asset].
  Future<double> quoteSendByNetwork({
    required NetworkType network,
    required int accountIndex,
    required double amount,
    required String recipient,
    required AssetTicker asset,
  }) async {
    final WdkManagerRpc manager = _requireManager;
    try {
      if (network == NetworkType.segwit) {
        final String value = (amount * getDenominationValue(AssetTicker.btc))
            .round()
            .toString();
        final String fee = await manager.quoteSendTransaction(
          network: 'bitcoin',
          accountIndex: accountIndex,
          to: recipient,
          value: value,
        );
        return double.parse(fee) / getDenominationValue(AssetTicker.btc);
      } else if (abstractedNetworks.contains(network)) {
        final String token = _tokenAddress(asset, network);
        // RN uses a fixed nominal amount (1000) for the quote.
        final String fee = await manager.abstractedAccountQuoteTransfer(
          network: network.id,
          accountIndex: accountIndex,
          recipient: recipient,
          token: token,
          amount: '1000',
          paymasterTokenAddress: token,
        );
        return double.parse(fee) / getDenominationValue(AssetTicker.usdt);
      }
      throw const WdkError(code: 'network', message: 'Unsupported network');
    } catch (e) {
      throw _mapInsufficientBalance(e);
    }
  }

  /// Builds, signs (in the worklet), and broadcasts a transfer.
  Future<SendResult> sendByNetwork({
    required NetworkType network,
    required int accountIndex,
    required double amount,
    required String recipient,
    required AssetTicker asset,
  }) async {
    final WdkManagerRpc manager = _requireManager;
    if (network == NetworkType.segwit) {
      final String value = (amount * getDenominationValue(AssetTicker.btc))
          .round()
          .toString();
      final Map<String, Object?> r = await manager.sendTransaction(
        network: network.id,
        accountIndex: accountIndex,
        to: recipient,
        value: value,
      );
      return SendResult(
        hash: (r['hash'] ?? '').toString(),
        fee: r['fee']?.toString(),
      );
    } else if (abstractedNetworks.contains(network)) {
      final String token = _tokenAddress(asset, network);
      final String amt = (amount * getDenominationValue(AssetTicker.usdt))
          .round()
          .toString();
      final Map<String, Object?> r = await manager.abstractedAccountTransfer(
        network: network.id,
        accountIndex: accountIndex,
        recipient: recipient,
        token: token,
        amount: amt,
        paymasterTokenAddress: token,
      );
      return SendResult(
        hash: (r['hash'] ?? '').toString(),
        fee: r['fee']?.toString(),
      );
    }
    throw const WdkError(code: 'network', message: 'Unsupported network');
  }

  String _tokenAddress(AssetTicker asset, NetworkType network) {
    final String? addr = smartContractAddresses[asset]?[network];
    if (addr == null) {
      throw WdkError(
        code: 'token',
        message: 'No ${asset.id} contract on ${network.id}',
      );
    }
    return addr;
  }

  Object _mapInsufficientBalance(Object error) {
    const List<String> patterns = <String>[
      'Insufficient balance',
      'Details: validator: callData reverts',
      'JSON is not a valid request object',
    ];
    final String msg = error.toString();
    if (patterns.any(msg.contains)) {
      return const WdkError(code: 'balance', message: 'Insufficient balance');
    }
    return error;
  }

  // --- Indexer reads -------------------------------------------------------

  /// Fetches balances for the enabled assets at the given addresses.
  Future<List<WalletBalance>> resolveWalletBalances(
    List<AssetTicker> enabledAssets,
    Map<NetworkType, String> addressMap,
  ) async {
    final WdkIndexerClient indexer =
        _indexer ?? (throw StateError('Indexer not configured'));
    final List<BalanceQuery> queries = <BalanceQuery>[];
    for (final AssetTicker asset in enabledAssets) {
      for (final NetworkType network
          in assetNetworks[asset] ?? const <NetworkType>[]) {
        final String? address = addressMap[network];
        if (address != null) {
          queries.add(
            BalanceQuery(
              blockchain: network.id,
              token: asset.id,
              address: address,
            ),
          );
        }
      }
    }
    final Map<String, TokenBalance> map = await indexer.batchTokenBalances(
      queries,
    );
    return map.values
        .map(
          (TokenBalance b) => WalletBalance(
            asset: AssetTicker.fromId(b.token),
            network: NetworkType.fromId(b.blockchain),
            amount: b.amount,
          ),
        )
        .toList();
  }

  /// Fetches transaction history for the enabled assets at the given addresses.
  Future<List<TransactionRecord>> resolveWalletTransactions(
    List<AssetTicker> enabledAssets,
    Map<NetworkType, String> addressMap,
  ) async {
    final WdkIndexerClient indexer =
        _indexer ?? (throw StateError('Indexer not configured'));
    final List<TransferQuery> queries = <TransferQuery>[];
    for (final AssetTicker asset in enabledAssets) {
      for (final NetworkType network
          in assetNetworks[asset] ?? const <NetworkType>[]) {
        final String? address = addressMap[network];
        if (address != null) {
          queries.add(
            TransferQuery(
              blockchain: network.id,
              token: asset.id,
              address: address,
            ),
          );
        }
      }
    }
    final Map<String, List<IndexerTransfer>> map = await indexer
        .batchTokenTransfers(queries);
    final List<TransactionRecord> out = <TransactionRecord>[];
    for (final List<IndexerTransfer> transfers in map.values) {
      for (final IndexerTransfer t in transfers) {
        out.add(
          TransactionRecord(
            transactionHash: t.transactionHash,
            network: NetworkType.fromId(t.blockchain),
            asset: AssetTicker.fromId(t.token),
            amount: t.amount,
            timestamp: DateTime.fromMillisecondsSinceEpoch(t.timestamp * 1000),
            from: t.from,
            to: t.to,
          ),
        );
      }
    }
    out.sort(
      (TransactionRecord a, TransactionRecord b) =>
          b.timestamp.compareTo(a.timestamp),
    );
    return out;
  }

  /// Process-wide preview-mode instance used by the app until the M2 binding.
  static final WdkService instance = WdkService();
}
