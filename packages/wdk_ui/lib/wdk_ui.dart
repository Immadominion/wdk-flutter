/// wdk_ui — a themeable Flutter widget kit for WDK wallets.
///
/// The Flutter analog of `@tetherto/wdk-uikit-react-native`. Theming is done
/// with a [WdkTheme] `ThemeExtension` driven by a brand primary color and a
/// brightness — mirroring the RN `<ThemeProvider defaultMode brandConfig={{
/// primaryColor }}>` API. Widgets are intentionally business-logic-free.
library;

import 'package:flutter/material.dart';

/// Brand + semantic colors for WDK widgets, attached to [ThemeData.extensions].
@immutable
class WdkTheme extends ThemeExtension<WdkTheme> {
  const WdkTheme({
    required this.primary,
    required this.background,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.success,
  });

  final Color primary;
  final Color background;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;
  final Color success;

  /// Derives a full palette from a brand [primaryColor] and [brightness],
  /// mirroring how the RN UI kit expands `brandConfig.primaryColor`.
  factory WdkTheme.fromBrand({
    required Color primaryColor,
    required Brightness brightness,
  }) {
    final bool dark = brightness == Brightness.dark;
    return WdkTheme(
      primary: primaryColor,
      background: dark ? const Color(0xFF0B0B0F) : const Color(0xFFFFFFFF),
      card: dark ? const Color(0xFF16161C) : const Color(0xFFF5F5F7),
      border: dark ? const Color(0xFF2A2A33) : const Color(0xFFE2E2E8),
      textPrimary: dark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0F),
      textSecondary: dark ? const Color(0xFF9A9AA6) : const Color(0xFF6B6B76),
      danger: const Color(0xFFFF3B30),
      success: const Color(0xFF34C759),
    );
  }

  @override
  WdkTheme copyWith({
    Color? primary,
    Color? background,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? danger,
    Color? success,
  }) {
    return WdkTheme(
      primary: primary ?? this.primary,
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  @override
  WdkTheme lerp(ThemeExtension<WdkTheme>? other, double t) {
    if (other is! WdkTheme) return this;
    return WdkTheme(
      primary: Color.lerp(primary, other.primary, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Builds a Material [ThemeData] carrying a [WdkTheme] for the given brand
/// color and brightness. Use this for `MaterialApp.theme`/`darkTheme`.
ThemeData buildWdkThemeData({
  required Color primaryColor,
  required Brightness brightness,
}) {
  final WdkTheme ext =
      WdkTheme.fromBrand(primaryColor: primaryColor, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: ext.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ),
    extensions: <ThemeExtension<dynamic>>[ext],
  );
}

/// Convenience accessor for the current [WdkTheme].
extension WdkThemeContext on BuildContext {
  WdkTheme get wdk =>
      Theme.of(this).extension<WdkTheme>() ??
      WdkTheme.fromBrand(
        primaryColor: const Color(0xFF1BA27A),
        brightness: Theme.of(this).brightness,
      );
}

/// Displays a portfolio/asset balance with an optional fiat line — the Flutter
/// analog of the RN `Balance` component.
class WdkBalance extends StatelessWidget {
  const WdkBalance({
    required this.value,
    this.currency = '',
    this.isLoading = false,
    super.key,
  });

  final String value;
  final String currency;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final WdkTheme t = context.wdk;
    if (isLoading) {
      return const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (currency.isNotEmpty) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            currency,
            style: TextStyle(color: t.textSecondary, fontSize: 18),
          ),
        ],
      ],
    );
  }
}
