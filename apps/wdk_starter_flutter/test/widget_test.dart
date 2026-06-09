import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wdk_flutter/wdk_flutter.dart';

import 'package:wdk_starter_flutter/main.dart';

void main() {
  testWidgets('App boots into the loading gate', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wdkConfigProvider.overrideWithValue(
            const WdkConfig(
              indexer: IndexerConfig(apiKey: '', url: 'https://example.test'),
              chains: <String, Object?>{},
            ),
          ),
        ],
        child: const WdkStarterApp(),
      ),
    );

    // The gate shows a loading indicator while the bootstrap future runs.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
