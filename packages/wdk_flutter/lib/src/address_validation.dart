import 'wdk_core.dart';

/// Per-network recipient-address validation for the send flow.
///
/// Bitcoin (SegWit) is validated with a full BIP-173 bech32 checksum. EVM is a
/// strict `0x`+40-hex format check. TON/TRON/Solana use charset + length checks
/// (sufficient to reject typos and pastes from the wrong chain); deeper
/// base58check/CRC validation can be layered in later without API changes.
class AddressValidator {
  const AddressValidator._();

  /// Returns true if [address] looks valid for [network].
  static bool isValid(NetworkType network, String address) {
    final String a = address.trim();
    if (a.isEmpty) return false;
    switch (network) {
      case NetworkType.ethereum:
      case NetworkType.polygon:
      case NetworkType.arbitrum:
      case NetworkType.plasma:
        return _isEvm(a);
      case NetworkType.segwit:
        return _isBech32(a, 'bc') || _isBech32(a, 'tb');
      case NetworkType.lightning:
        // BOLT-11 invoices, not addresses.
        return a.toLowerCase().startsWith('ln');
      case NetworkType.ton:
        return _isTon(a);
      case NetworkType.tron:
        return _isTron(a);
      case NetworkType.solana:
        return _isSolana(a);
    }
  }

  /// A human-readable reason an address is invalid, or null if it is valid.
  static String? validationError(NetworkType network, String address) {
    if (isValid(network, address)) return null;
    return 'Invalid ${network.id} address';
  }

  static bool _isEvm(String a) => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(a);

  static const String _b58 =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static bool _isBase58(String a) => a.split('').every(_b58.contains);

  static bool _isTron(String a) =>
      a.length == 34 && a.startsWith('T') && _isBase58(a);

  static bool _isSolana(String a) =>
      a.length >= 32 && a.length <= 44 && _isBase58(a);

  static final RegExp _b64url = RegExp(r'^[A-Za-z0-9_-]+$');
  static bool _isTon(String a) => a.length == 48 && _b64url.hasMatch(a);

  // --- BIP-173 bech32 ------------------------------------------------------

  static const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static bool _isBech32(String input, String expectedHrp) {
    final String s = input;
    // Reject mixed case (bech32 must be all-lower or all-upper).
    if (s != s.toLowerCase() && s != s.toUpperCase()) return false;
    final String lower = s.toLowerCase();
    final int sep = lower.lastIndexOf('1');
    if (sep < 1 || sep + 7 > lower.length) return false;
    final String hrp = lower.substring(0, sep);
    if (hrp != expectedHrp) return false;
    final String dataPart = lower.substring(sep + 1);
    final List<int> data = <int>[];
    for (int i = 0; i < dataPart.length; i++) {
      final int v = _charset.indexOf(dataPart[i]);
      if (v == -1) return false;
      data.add(v);
    }
    return _verifyChecksum(hrp, data);
  }

  static int _polymod(List<int> values) {
    const List<int> gen = <int>[
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    int chk = 1;
    for (final int v in values) {
      final int top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (int i = 0; i < 5; i++) {
        if (((top >> i) & 1) != 0) chk ^= gen[i];
      }
    }
    return chk;
  }

  static List<int> _hrpExpand(String hrp) {
    final List<int> out = <int>[];
    for (int i = 0; i < hrp.length; i++) {
      out.add(hrp.codeUnitAt(i) >> 5);
    }
    out.add(0);
    for (int i = 0; i < hrp.length; i++) {
      out.add(hrp.codeUnitAt(i) & 31);
    }
    return out;
  }

  static bool _verifyChecksum(String hrp, List<int> data) =>
      _polymod(<int>[..._hrpExpand(hrp), ...data]) == 1;
}
