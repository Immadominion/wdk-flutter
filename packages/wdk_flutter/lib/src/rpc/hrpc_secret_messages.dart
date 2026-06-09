import 'dart:typed_data';

import 'compact_encoding.dart';

/// Byte-exact Dart port of the WDK **secret-manager** HRPC message codecs
/// (`spec/hrpc/messages.js` in `@tetherto/wdk-react-native-provider`).
///
/// Each message is a `uint` flags byte followed by the present fields. A field
/// is "present" by JS truthiness — a non-zero number / non-empty string — so we
/// reproduce that exactly. Verified against `tools/parity/secret_manager_vectors.json`.
class SecretManagerMessages {
  const SecretManagerMessages._();

  static const String _ns = '@tetherto/wdk-secret-manager';

  static bool _str(Object? v) => v != null && (v as String).isNotEmpty;
  static bool _num(Object? v) => v != null && (v as num) != 0;

  /// Encodes [m] for the message [name]; returns the message-body bytes.
  static Uint8List encode(String name, Map<String, Object?> m) {
    final CompactEncoder e = CompactEncoder();
    switch (name) {
      case '$_ns/command-workletStart-request':
        final int flags = _num(m['enableDebugLogs']) ? 1 : 0;
        e.uint(flags);
        if (flags & 1 != 0) e.uint(m['enableDebugLogs'] as int);

      case '$_ns/command-workletStart-response':
      case '$_ns/command-workletStop-response':
        final int flags = _str(m['status']) ? 1 : 0;
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['status'] as String);

      case '$_ns/command-workletStop-request':
        final int flags = _str(m['payload']) ? 1 : 0;
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['payload'] as String);

      case '$_ns/command-generateAndEncrypt-request':
        final int flags =
            (_str(m['passkey']) ? 1 : 0) |
            (_str(m['salt']) ? 2 : 0) |
            (_str(m['seedPhrase']) ? 4 : 0) |
            (_str(m['derivedKey']) ? 8 : 0);
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['passkey'] as String);
        if (flags & 2 != 0) e.string(m['salt'] as String);
        if (flags & 4 != 0) e.string(m['seedPhrase'] as String);
        if (flags & 8 != 0) e.string(m['derivedKey'] as String);

      case '$_ns/command-generateAndEncrypt-response':
        final int flags =
            (_str(m['encryptedEntropy']) ? 1 : 0) |
            (_str(m['encryptedSeed']) ? 2 : 0);
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['encryptedEntropy'] as String);
        if (flags & 2 != 0) e.string(m['encryptedSeed'] as String);

      case '$_ns/command-decrypt-request':
        final int flags =
            (_str(m['passkey']) ? 1 : 0) |
            (_str(m['salt']) ? 2 : 0) |
            (_str(m['encryptedData']) ? 4 : 0) |
            (_str(m['derivedKey']) ? 8 : 0);
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['passkey'] as String);
        if (flags & 2 != 0) e.string(m['salt'] as String);
        if (flags & 4 != 0) e.string(m['encryptedData'] as String);
        if (flags & 8 != 0) e.string(m['derivedKey'] as String);

      case '$_ns/command-decrypt-response':
        final int flags = _str(m['result']) ? 1 : 0;
        e.uint(flags);
        if (flags & 1 != 0) e.string(m['result'] as String);

      case '$_ns/command-log-request':
        final int flags = (_num(m['type']) ? 1 : 0) | (_str(m['data']) ? 2 : 0);
        e.uint(flags);
        if (flags & 1 != 0) e.uint(m['type'] as int); // log-type enum = uint
        if (flags & 2 != 0) e.string(m['data'] as String);

      default:
        throw ArgumentError('Unknown secret-manager message: $name');
    }
    return e.takeBytes();
  }

  /// Decodes the message [name] from [bytes], mirroring the JS decode shapes
  /// (absent strings → null, absent numbers/enums → 0).
  static Map<String, Object?> decode(String name, Uint8List bytes) {
    final CompactDecoder d = CompactDecoder(bytes);
    final int flags = d.uint();
    switch (name) {
      case '$_ns/command-workletStart-request':
        return <String, Object?>{
          'enableDebugLogs': flags & 1 != 0 ? d.uint() : 0,
        };
      case '$_ns/command-workletStart-response':
      case '$_ns/command-workletStop-response':
        return <String, Object?>{'status': flags & 1 != 0 ? d.string() : null};
      case '$_ns/command-workletStop-request':
        return <String, Object?>{'payload': flags & 1 != 0 ? d.string() : null};
      case '$_ns/command-generateAndEncrypt-request':
        return <String, Object?>{
          'passkey': flags & 1 != 0 ? d.string() : null,
          'salt': flags & 2 != 0 ? d.string() : null,
          'seedPhrase': flags & 4 != 0 ? d.string() : null,
          'derivedKey': flags & 8 != 0 ? d.string() : null,
        };
      case '$_ns/command-generateAndEncrypt-response':
        return <String, Object?>{
          'encryptedEntropy': flags & 1 != 0 ? d.string() : null,
          'encryptedSeed': flags & 2 != 0 ? d.string() : null,
        };
      case '$_ns/command-decrypt-request':
        return <String, Object?>{
          'passkey': flags & 1 != 0 ? d.string() : null,
          'salt': flags & 2 != 0 ? d.string() : null,
          'encryptedData': flags & 4 != 0 ? d.string() : null,
          'derivedKey': flags & 8 != 0 ? d.string() : null,
        };
      case '$_ns/command-decrypt-response':
        return <String, Object?>{'result': flags & 1 != 0 ? d.string() : null};
      case '$_ns/command-log-request':
        return <String, Object?>{
          'type': flags & 1 != 0 ? d.uint() : 0,
          'data': flags & 2 != 0 ? d.string() : null,
        };
      default:
        throw ArgumentError('Unknown secret-manager message: $name');
    }
  }
}
