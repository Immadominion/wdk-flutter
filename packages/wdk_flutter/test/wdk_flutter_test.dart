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

  group('WdkService.getDenominationValue', () {
    test('BTC has 8 decimals; USDT/XAUT have 6', () {
      final WdkService svc = WdkService.instance;
      expect(svc.getDenominationValue(AssetTicker.btc), 8);
      expect(svc.getDenominationValue(AssetTicker.usdt), 6);
      expect(svc.getDenominationValue(AssetTicker.xaut), 6);
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
