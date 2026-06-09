import 'package:flutter_test/flutter_test.dart';
import 'package:wdk_flutter/wdk_flutter.dart';

void main() {
  group('EVM (ethereum/polygon/arbitrum)', () {
    test('accepts a 0x + 40-hex address', () {
      const String a = '0x52908400098527886E0F7030069857D2E4169EE7';
      expect(AddressValidator.isValid(NetworkType.ethereum, a), isTrue);
      expect(AddressValidator.isValid(NetworkType.polygon, a), isTrue);
      expect(AddressValidator.isValid(NetworkType.arbitrum, a), isTrue);
    });

    test('rejects malformed EVM addresses', () {
      expect(AddressValidator.isValid(NetworkType.ethereum, '0x123'), isFalse);
      expect(
        AddressValidator.isValid(NetworkType.ethereum, '52908400098527886E0F7030069857D2E4169EE7'),
        isFalse,
      );
    });
  });

  group('Bitcoin SegWit (bech32 checksum)', () {
    test('accepts a valid BIP-173 bech32 address', () {
      // BIP-173 test vector.
      const String a = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
      expect(AddressValidator.isValid(NetworkType.segwit, a), isTrue);
    });

    test('rejects a bech32 address with a corrupted checksum', () {
      const String a = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5';
      expect(AddressValidator.isValid(NetworkType.segwit, a), isFalse);
    });

    test('rejects mixed-case bech32', () {
      const String a = 'bc1Qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
      expect(AddressValidator.isValid(NetworkType.segwit, a), isFalse);
    });
  });

  group('TRON / Solana / TON format checks', () {
    test('TRON: 34 chars, T prefix, base58', () {
      expect(
        AddressValidator.isValid(NetworkType.tron, 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE'),
        isTrue,
      );
      expect(AddressValidator.isValid(NetworkType.tron, 'XQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE'), isFalse);
    });

    test('Solana: base58, 32–44 chars', () {
      expect(
        AddressValidator.isValid(
            NetworkType.solana, 'So11111111111111111111111111111111111111112'),
        isTrue,
      );
      expect(AddressValidator.isValid(NetworkType.solana, 'not-base58-0OIl'), isFalse);
    });

    test('TON: 48-char base64url', () {
      expect(
        AddressValidator.isValid(
            NetworkType.ton, 'EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N'),
        isTrue,
      );
      expect(AddressValidator.isValid(NetworkType.ton, 'too-short'), isFalse);
    });
  });

  test('validationError returns null when valid, a message when not', () {
    expect(
      AddressValidator.validationError(
          NetworkType.ethereum, '0x52908400098527886E0F7030069857D2E4169EE7'),
      isNull,
    );
    expect(
      AddressValidator.validationError(NetworkType.ethereum, 'nope'),
      contains('Invalid'),
    );
  });
}
