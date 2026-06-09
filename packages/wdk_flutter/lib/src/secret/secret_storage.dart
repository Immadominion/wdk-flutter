import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage keys for the secret manager, matching the RN provider
/// (`WDK_STORAGE_SEED`, `WDK_STORAGE_ENTROPY`, `WDK_STORAGE_SALT`).
enum SecretKey {
  seed('seed'),
  entropy('entropy'),
  salt('salt');

  const SecretKey(this.id);
  final String id;

  /// Mirrors `WdkSecretManagerStorage.getServiceForItem`.
  String get service => 'wdk.secretManager.$id';
}

/// Encrypted-blob storage for the seed/entropy/salt. Values are hex strings.
///
/// The RN provider gates the `seed` item behind device biometrics via
/// react-native-keychain. The Flutter equivalent gates reads with `local_auth`
/// at the unlock step (see the authorize flow); at-rest protection is provided
/// by the platform keystore via [FlutterSecureStorageSecretStorage].
abstract class SecretStorage {
  Future<void> write(SecretKey key, String hexValue);
  Future<String?> read(SecretKey key);
  Future<bool> contains(SecretKey key);
  Future<void> delete(SecretKey key);
  Future<void> deleteAll();
}

/// In-memory implementation for tests.
class InMemorySecretStorage implements SecretStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> write(SecretKey key, String hexValue) async =>
      _store[key.service] = hexValue;

  @override
  Future<String?> read(SecretKey key) async => _store[key.service];

  @override
  Future<bool> contains(SecretKey key) async => _store.containsKey(key.service);

  @override
  Future<void> delete(SecretKey key) async => _store.remove(key.service);

  @override
  Future<void> deleteAll() async => _store.clear();
}

/// Production implementation backed by Keychain (iOS) / Keystore (Android).
class FlutterSecureStorageSecretStorage implements SecretStorage {
  FlutterSecureStorageSecretStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(SecretKey key, String hexValue) =>
      _storage.write(key: key.service, value: hexValue);

  @override
  Future<String?> read(SecretKey key) => _storage.read(key: key.service);

  @override
  Future<bool> contains(SecretKey key) =>
      _storage.containsKey(key: key.service);

  @override
  Future<void> delete(SecretKey key) => _storage.delete(key: key.service);

  @override
  Future<void> deleteAll() async {
    for (final SecretKey k in SecretKey.values) {
      await _storage.delete(key: k.service);
    }
  }
}
