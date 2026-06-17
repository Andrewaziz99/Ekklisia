// lib/core/theme/brightness_colors.dart
// ─────────────────────────────────────────────────────────────────────────────
// Helper to get theme colors based on brightness (light/dark mode)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'colors.dart';

/// Helper class to get colors dynamically based on brightness
abstract class BrightnessColors {

  /// Get background color based on brightness
  static Color bgPrimary(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgPrimary : EkklisiaColors.lightBgPrimary;

  static Color bgDeep(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgDeep : EkklisiaColors.lightBgDeep;

  static Color bgMid(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgMid : EkklisiaColors.lightBgMid;

  static Color bgElevated(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgElevated : EkklisiaColors.lightBgElevated;

  static Color bgParchment(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgParchment : EkklisiaColors.lightBgParchment;

  static Color bgParchmentDim(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBgParchmentDim : EkklisiaColors.lightBgParchmentDim;

  /// Get text color based on brightness
  static Color textPrimary(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkTextPrimary : EkklisiaColors.lightTextPrimary;

  static Color textSecondary(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkTextSecondary : EkklisiaColors.lightTextSecondary;

  static Color textCream(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkTextCream : EkklisiaColors.lightTextCream;

  static Color textOnParchment(Brightness brightness) =>
    brightness == Brightness.dark
        ? EkklisiaColors.darkTextOnParchment
        : EkklisiaColors.lightTextOnParchment;

  /// Get gold/accent color based on brightness
  static Color gold(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkGold : EkklisiaColors.lightGold;

  static Color goldLight(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkGoldLight : EkklisiaColors.lightGoldLight;

  static Color goldDim(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkGoldDim : EkklisiaColors.lightGoldDim;

  static Color goldSubtle(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkGoldSubtle : EkklisiaColors.lightGoldSubtle;

  static Color goldBorder(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkGoldBorder : EkklisiaColors.lightGoldBorder;

  /// Get category colors based on brightness
  static Color maroon(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkMaroon : EkklisiaColors.lightMaroon;

  static Color maroonMid(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkMaroonMid : EkklisiaColors.lightMaroonMid;

  static Color maroonDark(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkMaroonDark : EkklisiaColors.lightMaroonDark;

  static Color plum(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkPlum : EkklisiaColors.lightPlum;

  static Color tealMid(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkTealMid : EkklisiaColors.lightTealMid;

  static Color tealDark(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkTealDark : EkklisiaColors.lightTealDark;

  static Color bronze(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBronze : EkklisiaColors.lightBronze;

  static Color ocean(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkOcean : EkklisiaColors.lightOcean;

  static Color forest(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkForest : EkklisiaColors.lightForest;

  /// Get gradient based on brightness
  static LinearGradient headerGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkHeaderGradient : EkklisiaColors.lightHeaderGradient;

  static LinearGradient bottomNavGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBottomNavGradient : EkklisiaColors.lightBottomNavGradient;

  static LinearGradient cardOverlayGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkCardOverlayGradient : EkklisiaColors.lightCardOverlayGradient;

  static LinearGradient splashGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkSplashGradient : EkklisiaColors.lightSplashGradient;

  static LinearGradient maroonCardGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkMaroonCardGradient : EkklisiaColors.lightMaroonCardGradient;

  static LinearGradient plumCardGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkPlumCardGradient : EkklisiaColors.lightPlumCardGradient;

  static LinearGradient bronzeCardGradient(Brightness brightness) =>
    brightness == Brightness.dark ? EkklisiaColors.darkBronzeCardGradient : EkklisiaColors.lightBronzeCardGradient;
}
