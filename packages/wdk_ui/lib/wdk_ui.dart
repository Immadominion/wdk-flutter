/// wdk_ui — a themeable Flutter widget kit for WDK wallets.
///
/// The Flutter analog of `@tetherto/wdk-uikit-react-native`. Theming uses a
/// [WdkTheme] `ThemeExtension` driven by a brand primary color and brightness
/// (mirroring the RN `<ThemeProvider defaultMode brandConfig={{ primaryColor }}>`
/// API). Widgets are intentionally business-logic-free: validation and data
/// shaping are injected by the consumer, so the kit has no `wdk_flutter`
/// dependency.
library;

export 'src/wdk_theme.dart';
export 'src/widgets.dart';
