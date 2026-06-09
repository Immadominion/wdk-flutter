import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdk_ui/wdk_ui.dart';

void main() {
  test('WdkTheme.fromBrand keeps the brand color and varies by brightness', () {
    const Color brand = Color(0xFF1BA27A);
    final WdkTheme dark =
        WdkTheme.fromBrand(primaryColor: brand, brightness: Brightness.dark);
    final WdkTheme light =
        WdkTheme.fromBrand(primaryColor: brand, brightness: Brightness.light);

    expect(dark.primary, brand);
    expect(light.primary, brand);
    expect(dark.background, isNot(equals(light.background)));
  });

  test('buildWdkThemeData attaches a WdkTheme extension', () {
    final ThemeData theme = buildWdkThemeData(
      primaryColor: const Color(0xFF1BA27A),
      brightness: Brightness.dark,
    );
    expect(theme.extension<WdkTheme>(), isNotNull);
    expect(theme.brightness, Brightness.dark);
  });

  Widget host(Widget child) => MaterialApp(
        theme: buildWdkThemeData(
          primaryColor: const Color(0xFF1BA27A),
          brightness: Brightness.dark,
        ),
        home: Scaffold(body: child),
      );

  testWidgets('WdkAddressInput shows an injected validation error', (tester) async {
    await tester.pumpWidget(host(
      WdkAddressInput(
        value: 'bad',
        onChanged: (_) {},
        validator: (String v) => v == 'ok' ? null : 'Invalid address',
      ),
    ));
    expect(find.text('Invalid address'), findsOneWidget);
  });

  testWidgets('WdkTransactionList renders rows and an empty state', (tester) async {
    await tester.pumpWidget(host(const WdkTransactionList(items: <WdkTxItem>[])));
    expect(find.text('No transactions yet'), findsOneWidget);

    await tester.pumpWidget(host(WdkTransactionList(items: <WdkTxItem>[
      const WdkTxItem(sent: true, token: 'USD₮', amount: '5.0', network: 'Ethereum'),
      const WdkTxItem(sent: false, token: 'BTC', amount: '0.01', network: 'Bitcoin'),
    ])));
    expect(find.text('Sent USD₮'), findsOneWidget);
    expect(find.text('Received BTC'), findsOneWidget);
  });

  testWidgets('WdkSeedPhrase hides words until revealed', (tester) async {
    await tester.pumpWidget(host(
      const WdkSeedPhrase(words: <String>['alpha', 'bravo', 'charlie']),
    ));
    expect(find.textContaining('alpha'), findsNothing);
    await tester.tap(find.text('Reveal'));
    await tester.pump();
    expect(find.textContaining('alpha'), findsOneWidget);
  });

  testWidgets('WdkAssetSelector emits the tapped option', (tester) async {
    WdkAssetOption? picked;
    await tester.pumpWidget(host(WdkAssetSelector(
      options: const <WdkAssetOption>[
        WdkAssetOption(symbol: 'BTC', name: 'Bitcoin'),
        WdkAssetOption(symbol: 'USD₮', name: 'Tether'),
      ],
      onSelected: (WdkAssetOption o) => picked = o,
    )));
    await tester.tap(find.text('Bitcoin'));
    expect(picked?.symbol, 'BTC');
  });

  testWidgets('WdkQrCode renders', (tester) async {
    await tester.pumpWidget(host(const WdkQrCode(data: 'bc1qexample', label: 'Scan')));
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byType(WdkQrCode), findsOneWidget);
  });
}
