import 'dart:convert';
import 'dart:typed_data';

/// Number of salt bytes (mirrors `MAX_BYTES` in the RN provider).
const int kWdkSaltBytes = 16;

/// Deterministically derives the 16-byte WDK encryption salt from a [prf]
/// (the device unique id in the RN starter).
///
/// Faithful port of `wdk-encryption-salt.ts`:
///   * take the local part before '@' (the full string when there is no '@'),
///   * UTF-8 encode it,
///   * write into a 16-byte buffer; if longer, keep the first 16 bytes;
///     otherwise pad the remaining bytes with the value 7.
Uint8List generateWdkSalt(String prf) {
  final String localPart = prf.split('@').first;
  final List<int> encoded = utf8.encode(localPart);
  final Uint8List out = Uint8List(kWdkSaltBytes);
  if (encoded.length > kWdkSaltBytes) {
    out.setRange(0, kWdkSaltBytes, encoded.sublist(0, kWdkSaltBytes));
  } else {
    out.setRange(0, encoded.length, encoded);
    out.fillRange(encoded.length, kWdkSaltBytes, 7);
  }
  return out;
}
