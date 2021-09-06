import 'package:flutter/painting.dart';

class AppColors {
  AppColors._();

  static const lightPrimary = Color(0xFF4527A0);
  static const lightPrimaryVariant = Color(0xFF673AB7);
  static const lightSecondary = Color(0xFF0091EA);
  static const lightSecondaryVariant = Color(0xFF00B0FF);
  static const lightBackground = Color(0xFFF2F0F7);
  static const lightSurface = Color(0xFFFBFAFD);
  static const lightError = Color(0xFFB00020);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightOnBackground = Color(0xFF000000);
  static const lightOnSurface = Color(0xFF000000);
  static const lightOnError = Color(0xFFFFFFFF);

  static const darkPrimary = Color(0xFF7C67BC);
  static const darkPrimaryVariant = Color(0xFF9474CC);
  static const darkSecondary = Color(0xFF4CB1F0);
  static const darkSecondaryVariant = Color(0xFF4CC7FF);
  static const darkBackground = Color(0xFF1B1922);
  static const darkSurface = Color(0xFF17161B);
  static const darkError = Color(0xFFCF6679);
  static const darkOnPrimary = Color(0xFFFFFFFF);
  static const darkOnSecondary = Color(0xFF000000);
  static const darkOnBackground = Color(0xFFFFFFFF);
  static const darkOnSurface = Color(0xFFFFFFFF);
  static const darkOnError = Color(0xFFFFFFFF);

  static const grey = Color(0xFFA4A6B3);

  static const g1 = Color(0xFFDE9FF8);
  static const g2 = Color(0xFFF64A77);
  static const g3 = Color(0xFFA723D8);

  static const g4 = Color(0xFF1F1761);
  static const g5 = Color(0xFF241857);
  static const g6 = Color(0xFF1C142A);

  static const darkGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      g4,
      g5,
      g6,
    ],
  );
  static const lightGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      g1,
      g2,
      g3,
    ],
  );
}
