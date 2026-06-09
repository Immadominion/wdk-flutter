import 'package:flutter_test/flutter_test.dart';
import 'package:wdk_flutter/wdk_flutter.dart';

void main() {
  group('WdkError.parse (worklet "code:X,msg:Y" codec)', () {
    test('decodes a well-formed worklet error', () {
      final WdkError? err = WdkError.parse('code:42,msg:Insufficient balance');
      expect(err, isNotNull);
      expect(err!.code, '42');
      expect(err.message, 'Insufficient balance');
    });

    test('maps biometric-cancelled code 13 to a friendly message', () {
      final WdkError? err = WdkError.parse('code:13,msg:cancelled');
      expect(err!.message, 'The biometric authentication was cancelled');
    });

    test('returns null for non-worklet error strings', () {
      expect(WdkError.parse('some random error'), isNull);
      expect(WdkError.parse(null), isNull);
    });

    test('serialize() round-trips the wire form', () {
      const WdkError err = WdkError(code: '7', message: 'boom');
      expect(err.serialize(), 'code:7,msg:boom');
    });
  });

  group('denominations (matching the RN provider)', () {
    test('denominationFor: BTC=1e8, USDT/XAUT=1e6', () {
      expect(denominationFor(AssetTicker.btc), BigInt.from(100000000));
      expect(denominationFor(AssetTicker.usdt), BigInt.from(1000000));
      expect(denominationFor(AssetTicker.xaut), BigInt.from(1000000));
    });

    test('decimalsFor: BTC=8, USDT/XAUT=6', () {
      expect(decimalsFor(AssetTicker.btc), 8);
      expect(decimalsFor(AssetTicker.usdt), 6);
      expect(decimalsFor(AssetTicker.xaut), 6);
    });

    test('WdkService.getDenominationValue returns the multiplier', () {
      expect(
        WdkService.instance.getDenominationValue(AssetTicker.btc),
        100000000,
      );
      expect(
        WdkService.instance.getDenominationValue(AssetTicker.usdt),
        1000000,
      );
    });
  });

  group('asset → network map matches the provider', () {
    test('BTC=SegWit only; XAUT=Ethereum only; USDT spans EVM+TON', () {
      expect(assetNetworks[AssetTicker.btc], <NetworkType>[NetworkType.segwit]);
      expect(assetNetworks[AssetTicker.xaut], <NetworkType>[
        NetworkType.ethereum,
      ]);
      expect(assetNetworks[AssetTicker.usdt], contains(NetworkType.ton));
    });

    test('USDT/XAUT contract addresses are present for Ethereum', () {
      expect(
        smartContractAddresses[AssetTicker.usdt]?[NetworkType.ethereum],
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      );
      expect(
        smartContractAddresses[AssetTicker.xaut]?[NetworkType.ethereum],
        isNotNull,
      );
    });
  });

  group('encryption salt (port of wdk-encryption-salt.ts)', () {
    test('is 16 bytes and pads short input with 7', () {
      final List<int> salt = generateWdkSalt('ab'); // 2 bytes -> pad 14 x 7
      expect(salt.length, 16);
      expect(salt[0], 'a'.codeUnitAt(0));
      expect(salt[1], 'b'.codeUnitAt(0));
      expect(salt.sublist(2).every((int b) => b == 7), isTrue);
    });

    test('takes the local part before @', () {
      final List<int> a = generateWdkSalt('device-id-123');
      final List<int> b = generateWdkSalt('device-id-123@ignored');
      expect(a, b);
    });
  });

  group('enums match the WDK wire ids', () {
    test('NetworkType.segwit maps to "bitcoin"; plasma is present', () {
      expect(NetworkType.segwit.id, 'bitcoin');
      expect(NetworkType.fromId('bitcoin'), NetworkType.segwit);
      expect(NetworkType.plasma.id, 'plasma');
    });
  });
}
