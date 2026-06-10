import 'worklet_rpc.dart';

/// Typed wrapper over the `wdkManager` worklet's HRPC methods, matching the
/// calls the RN provider makes (`workletStart`, `getAddress`,
/// `getAbstractedAddress`, `quoteSendTransaction`,
/// `abstractedAccountQuoteTransfer`, `sendTransaction`,
/// `abstractedAccountTransfer`).
class WdkManagerRpc {
  WdkManagerRpc(this._rpc);
  final WorkletRpc _rpc;

  /// Boots the manager worklet with a seed phrase and serialized chains config.
  Future<void> workletStart({
    required String seedPhrase,
    required String configJson,
    int enableDebugLogs = 0,
  }) async {
    await _rpc.call('workletStart', <String, Object?>{
      'enableDebugLogs': enableDebugLogs,
      'seedPhrase': seedPhrase,
      'config': configJson,
    });
  }

  /// Tears down the manager worklet (HRPC `dispose`, command 14, send-only).
  Future<void> dispose() async {
    await _rpc.call('dispose', <String, Object?>{});
  }

  /// Direct (non-abstracted) address — used for Bitcoin/SegWit.
  Future<String> getAddress({
    required String network,
    required int accountIndex,
  }) async {
    final Map<String, Object?> r = await _rpc.call(
      'getAddress',
      <String, Object?>{'network': network, 'accountIndex': accountIndex},
    );
    return (r['address'] ?? '').toString();
  }

  /// ERC-4337 abstracted account address — used for EVM/TON.
  Future<String> getAbstractedAddress({
    required String network,
    required int accountIndex,
  }) async {
    final Map<String, Object?> r = await _rpc.call(
      'getAbstractedAddress',
      <String, Object?>{'network': network, 'accountIndex': accountIndex},
    );
    return (r['address'] ?? '').toString();
  }

  /// Bitcoin fee quote. [value] is in satoshis as a string.
  Future<String> quoteSendTransaction({
    required String network,
    required int accountIndex,
    required String to,
    required String value,
  }) async {
    final Map<String, Object?> r = await _rpc.call(
      'quoteSendTransaction',
      <String, Object?>{
        'network': network,
        'accountIndex': accountIndex,
        'options': <String, Object?>{'to': to, 'value': value},
      },
    );
    return (r['fee'] ?? '0').toString();
  }

  /// EVM/TON abstracted-transfer fee quote.
  Future<String> abstractedAccountQuoteTransfer({
    required String network,
    required int accountIndex,
    required String recipient,
    required String token,
    required String amount,
    required String paymasterTokenAddress,
  }) async {
    final Map<String, Object?> r = await _rpc.call(
      'abstractedAccountQuoteTransfer',
      <String, Object?>{
        'network': network,
        'accountIndex': accountIndex,
        'options': <String, Object?>{
          'recipient': recipient,
          'token': token,
          'amount': amount,
        },
        'config': <String, Object?>{
          'paymasterToken': <String, Object?>{'address': paymasterTokenAddress},
        },
      },
    );
    return (r['fee'] ?? '0').toString();
  }

  /// Bitcoin send. Returns the raw worklet response (hash, fee, …).
  Future<Map<String, Object?>> sendTransaction({
    required String network,
    required int accountIndex,
    required String to,
    required String value,
  }) {
    return _rpc.call('sendTransaction', <String, Object?>{
      'network': network,
      'accountIndex': accountIndex,
      'options': <String, Object?>{'to': to, 'value': value},
    });
  }

  /// EVM/TON abstracted transfer. Returns the raw worklet response.
  Future<Map<String, Object?>> abstractedAccountTransfer({
    required String network,
    required int accountIndex,
    required String recipient,
    required String token,
    required String amount,
    required String paymasterTokenAddress,
  }) {
    return _rpc.call('abstractedAccountTransfer', <String, Object?>{
      'network': network,
      'accountIndex': accountIndex,
      'options': <String, Object?>{
        'recipient': recipient,
        'token': token,
        'amount': amount,
      },
      'config': <String, Object?>{
        'paymasterToken': <String, Object?>{'address': paymasterTokenAddress},
      },
    });
  }
}
