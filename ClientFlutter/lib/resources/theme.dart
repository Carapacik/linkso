import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:linkso/resources/palette.dart';

final _lightTextTheme = GoogleFonts.nunitoSansTextTheme().apply(bodyColor: const Color(0xFF222222));
final _darkTextTheme = GoogleFonts.nunitoSansTextTheme().apply(bodyColor: Colors.white);

extension TextThemeExt on TextTheme {
  TextStyle get b48 => bodyText1!.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      );

  TextStyle get b36 => bodyText1!.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
      );

  TextStyle get b24 => bodyText1!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.5,
      );

  TextStyle get m24 => bodyText1!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.normal,
      );

  TextStyle get b20 => bodyText1!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.5,
      );

  TextStyle get b18 => bodyText2!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.5,
      );

  TextStyle get m18 => bodyText1!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.6,
      );

  TextStyle get m16 => bodyText2!.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.normal,
      );

  TextStyle get n14 => bodyText2!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.normal,
      );
}

final ThemeData lightTheme = ThemeData.light().copyWith(
  primaryColor: AppColors.lightPrimary,
  primaryColorDark: Color(0xFF301B70),
  primaryColorLight: Color(0xFF8F7DC6),
  secondaryHeaderColor: Color(0xFF9988CB),
  toggleableActiveColor: AppColors.lightPrimary,
  indicatorColor: Color(0xFF4527A0),
  bottomAppBarColor: Color(0xFF1B1922),
  dividerColor: Color(0x1FFFFFFF),
  disabledColor: Color(0x62FFFFFF),
  backgroundColor: Color(0xFF1B1922),
  canvasColor: Color(0xFF1B1922),
  cardColor: Color(0xFFFFFFFF),
  dialogBackgroundColor: Color(0xFF17161B),
  scaffoldBackgroundColor: Color(0xFF121212),
  errorColor: _darkColorScheme.error,
  appBarTheme: AppBarTheme(
    color: Color(0xFF4527A0),
    iconTheme: IconThemeData(color: _lightColorScheme.onSurface),
  ),
  // Icon theme here
  textTheme: _lightTextTheme,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()
    },
  ),
  iconTheme: IconThemeData(color: _lightColorScheme.onSurface),
  textSelectionTheme: TextSelectionThemeData(selectionColor: _lightColorScheme.secondaryVariant),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  colorScheme: _lightColorScheme,
);

const ColorScheme _lightColorScheme = ColorScheme(
  primary: AppColors.lightPrimary,
  primaryVariant: AppColors.lightPrimaryVariant,
  secondary: AppColors.lightSecondary,
  secondaryVariant: AppColors.lightSecondaryVariant,
  background: AppColors.lightBackground,
  error: AppColors.lightError,
  surface: AppColors.lightSurface,
  onBackground: AppColors.lightOnBackground,
  onPrimary: AppColors.lightOnPrimary,
  onSecondary: AppColors.lightOnSecondary,
  onSurface: AppColors.lightOnSurface,
  onError: AppColors.lightOnError,
  brightness: Brightness.light,
);

final ThemeData darkTheme = ThemeData.dark().copyWith(
  primaryColor: AppColors.darkPrimary,
  primaryColorDark: Color(0xFF635296),
  primaryColorLight: Color(0xFFB0A4D7),
  secondaryHeaderColor: Color(0xFFB7ABDA),
  toggleableActiveColor: AppColors.darkPrimary,
  indicatorColor: Color(0xFF7C67BC),
  bottomAppBarColor: Color(0xFFF2F0F7),
  dividerColor: Color(0x1F000000),
  disabledColor: Color(0x61000000),
  backgroundColor: Color(0xFFF2F0F7),
  canvasColor: Color(0xFFF2F0F7),
  cardColor: Color(0xFF100F0F),
  dialogBackgroundColor: Color(0xFFFBFAFD),
  scaffoldBackgroundColor: Color(0xFFFFFFFF),
  errorColor: _darkColorScheme.error,
  appBarTheme: AppBarTheme(
    color: Color(0xFF121212),
    iconTheme: IconThemeData(color: _darkColorScheme.onSurface),
  ),
  textTheme: _darkTextTheme,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()
    },
  ),
  iconTheme: IconThemeData(color: _darkColorScheme.onSurface),
  textSelectionTheme: TextSelectionThemeData(selectionColor: _darkColorScheme.secondaryVariant),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  colorScheme: _darkColorScheme,
);

const ColorScheme _darkColorScheme = ColorScheme(
  primary: AppColors.darkPrimary,
  primaryVariant: AppColors.darkPrimaryVariant,
  secondary: AppColors.darkSecondary,
  secondaryVariant: AppColors.darkSecondaryVariant,
  background: AppColors.darkBackground,
  error: AppColors.darkError,
  surface: AppColors.darkSurface,
  onBackground: AppColors.darkOnBackground,
  onPrimary: AppColors.darkOnPrimary,
  onSecondary: AppColors.darkOnSecondary,
  onSurface: AppColors.darkOnSurface,
  onError: AppColors.darkOnError,
  brightness: Brightness.dark,
);
