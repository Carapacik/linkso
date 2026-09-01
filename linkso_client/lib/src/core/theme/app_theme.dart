import 'package:linkso_client/src/core/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

ThemeData createLightTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: linkSoPrimaryColor).copyWith(
    primary: linkSoPrimaryColor,
    secondary: linkSoAccentColor,
    surface: linkSoLightSurfaceColor,
    onSurface: linkSoLightContentColor,
    outline: linkSoLightLineColor,
  );

  return _createTheme(colorScheme, linkSoLightCanvasColor);
}

ThemeData createDarkTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: linkSoDarkPrimaryColor, brightness: Brightness.dark)
      .copyWith(
        primary: linkSoDarkPrimaryColor,
        secondary: linkSoDarkAccentColor,
        surface: linkSoDarkSurfaceColor,
        onSurface: linkSoDarkContentColor,
        outline: linkSoDarkLineColor,
      );

  return _createTheme(colorScheme, linkSoDarkCanvasColor);
}

ThemeData _createTheme(ColorScheme colorScheme, Color canvasColor) {
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: canvasColor,
    appBarTheme: AppBarTheme(
      backgroundColor: canvasColor,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );

  final TextTheme baseTextTheme = baseTheme.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    fontFamily: 'Nunito',
  );
  final TextTheme textTheme = baseTextTheme.copyWith(
    displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
    bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400),
    labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
  );

  return baseTheme.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
      hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
      helperStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
    ),
    navigationBarTheme: NavigationBarThemeData(labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium)),
  );
}
