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
}
