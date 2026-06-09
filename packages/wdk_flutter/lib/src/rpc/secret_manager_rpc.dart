import 'worklet_rpc.dart';

/// Result of `commandGenerateAndEncrypt`: the encrypted entropy + seed blobs
/// (hex) the app persists in secure storage.
class EncryptedSecret {
  const EncryptedSecret({
    required this.encryptedEntropy,
    required this.encryptedSeed,
  });
  final String encryptedEntropy;
  final String encryptedSeed;
}

/// Typed wrapper over the `wdkSecretManager` worklet's HRPC commands
/// (`commandWorkletStart`, `commandGenerateAndEncrypt`, `commandDecrypt`,
/// `commandWorkletStop`).
class SecretManagerRpc {
  SecretManagerRpc(this._rpc);
  final WorkletRpc _rpc;

  /// Starts the secret-manager worklet; returns its status string.
  Future<String> commandWorkletStart({int enableDebugLogs = 0}) async {
    final Map<String, Object?> r = await _rpc.call(
      'commandWorkletStart',
      <String, Object?>{'enableDebugLogs': enableDebugLogs},
    );
    return (r['status'] ?? '').toString();
  }

  /// Generates (or imports, when [seedPhrase] is given) and encrypts a secret.
  Future<EncryptedSecret> commandGenerateAndEncrypt({
    required String passkey,
    required String saltHex,
    String? seedPhrase,
  }) async {
    final Map<String, Object?> r =
        await _rpc.call('commandGenerateAndEncrypt', <String, Object?>{
      'passkey': passkey,
      'salt': saltHex,
      'seedPhrase': ?seedPhrase,
    });
    return EncryptedSecret(
      encryptedEntropy: (r['encryptedEntropy'] ?? '').toString(),
      encryptedSeed: (r['encryptedSeed'] ?? '').toString(),
    );
  }

  /// Decrypts [encryptedDataHex]; returns the plaintext result (hex entropy).
  Future<String> commandDecrypt({
    required String passkey,
    required String saltHex,
    required String encryptedDataHex,
  }) async {
    final Map<String, Object?> r =
        await _rpc.call('commandDecrypt', <String, Object?>{
      'passkey': passkey,
      'salt': saltHex,
      'encryptedData': encryptedDataHex,
    });
    return (r['result'] ?? '').toString();
  }

  Future<void> commandWorkletStop() async {
    await _rpc.call('commandWorkletStop', <String, Object?>{});
  }
}
