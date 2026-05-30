import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brightness_colors.dart';
import 'colors.dart';

/// Centralised ThemeData + helpers.
/// All UI components in the app reference this — never hardcode colours.
class EkklisiaTheme {
  EkklisiaTheme._();

  // ── Text Styles (Dynamic based on brightness) ────────────────────────────

  /// Get text styles that adapt to brightness
  static TextStyle titleLarge(Brightness brightness) => TextStyle(
    color: BrightnessColors.goldLight(brightness),
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
  );

  static TextStyle headingMedium(Brightness brightness) => TextStyle(
    color: BrightnessColors.textPrimary(brightness),
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle headingSmall(Brightness brightness) => TextStyle(
    color: BrightnessColors.textPrimary(brightness),
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyMedium(Brightness brightness) => TextStyle(
    color: BrightnessColors.textPrimary(brightness),
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodySmall(Brightness brightness) => TextStyle(
    color: BrightnessColors.textSecondary(brightness),
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle labelGold(Brightness brightness) => TextStyle(
    color: BrightnessColors.gold(brightness),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  // ── Legacy static text styles (for backwards compatibility) ───────────────

  static const TextStyle titleLargeStatic = TextStyle(
    color: EkklisiaColors.goldLight,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
  );

  static const TextStyle headingMediumStatic = TextStyle(
    color: EkklisiaColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle headingSmallStatic = TextStyle(
    color: EkklisiaColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyMediumStatic = TextStyle(
    color: EkklisiaColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle bodySmallStatic = TextStyle(
    color: EkklisiaColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelGoldStatic = TextStyle(
    color: EkklisiaColors.gold,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  static const TextStyle arabicBody = TextStyle(
    fontFamily: 'Scheherazade',
    color: EkklisiaColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.8,
  );

  static const TextStyle copticBody = TextStyle(
    fontFamily: 'CopticFont',
    color: EkklisiaColors.textPrimary,
    fontSize: 16,
    height: 1.8,
  );

  static const TextStyle greekBody = TextStyle(
    fontFamily: 'GFSDidot',
    color: EkklisiaColors.textPrimary,
    fontSize: 16,
    height: 1.7,
  );

  // ── Dynamic ThemeData Builder ──────────────────────────────────────────────

  /// Build theme data based on brightness (light/dark mode)
  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bgPrimary = BrightnessColors.bgPrimary(brightness);
    final bgDeep = BrightnessColors.bgDeep(brightness);
    final bgMid = BrightnessColors.bgMid(brightness);
    final bgElevated = BrightnessColors.bgElevated(brightness);
    final textPrimary = BrightnessColors.textPrimary(brightness);
    final textSecondary = BrightnessColors.textSecondary(brightness);
    final textCream = BrightnessColors.textCream(brightness);
    final gold = BrightnessColors.gold(brightness);
    final goldLight = BrightnessColors.goldLight(brightness);
    final goldDim = BrightnessColors.goldDim(brightness);
    final goldBorder = BrightnessColors.goldBorder(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: gold,

      colorScheme: isDark
          ? ColorScheme.dark(
              primary: gold,
              secondary: BrightnessColors.maroon(brightness),
              surface: bgMid,
              onPrimary: bgDeep,
              onSecondary: textCream,
              onSurface: textPrimary,
            )
          : ColorScheme.light(
              primary: gold,
              secondary: BrightnessColors.maroon(brightness),
              surface: bgMid,
              onPrimary: bgDeep,
              onSecondary: textCream,
              onSurface: textPrimary,
            ),

      appBarTheme: AppBarTheme(
        backgroundColor: bgDeep,
        foregroundColor: goldLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: goldLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bgDeep,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: gold),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgDeep,
        selectedItemColor: gold,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: bgMid,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: goldBorder, width: 0.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: bgDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: BorderSide(color: goldBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: goldBorder,
            width: 0.5,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: bgElevated,
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 11,
        ),
        selectedColor: BrightnessColors.goldLight(brightness).withValues(alpha: 0.2),
        side: BorderSide(color: goldBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: DividerThemeData(
        color: goldBorder,
        thickness: 0.5,
      ),

      iconTheme: IconThemeData(color: gold),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: goldLight,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(
          color: gold,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Convenience Getters (Dynamic) ──────────────────────────────────────────

  /// Get theme data for dark mode
  static ThemeData get darkTheme => buildTheme(Brightness.dark);

  /// Get theme data for light mode
  static ThemeData get lightTheme => buildTheme(Brightness.light);

  // ── Convenience Decorations (Dynamic) ──────────────────────────────────────

  /// Card decoration based on brightness
  static BoxDecoration byzantineCard(Brightness brightness) => BoxDecoration(
    color: BrightnessColors.bgMid(brightness),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: BrightnessColors.goldBorder(brightness), width: 0.5),
  );

  /// Gold-framed header with background gradient
  static BoxDecoration headerDecoration(Brightness brightness) => BoxDecoration(
    gradient: BrightnessColors.headerGradient(brightness),
    border: Border(
      bottom: BorderSide(color: BrightnessColors.goldBorder(brightness), width: 0.5),
    ),
  );

  /// Parchment-style container for text content
  static BoxDecoration parchmentDecoration(Brightness brightness) => BoxDecoration(
    color: EkklisiaColors.bgParchment,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: EkklisiaColors.goldDim, width: 0.8),
    boxShadow: [
      BoxShadow(
        color: BrightnessColors.bgDeep(brightness).withValues(alpha: 0.5),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Legacy Static Decorations ──────────────────────────────────────────────

  static BoxDecoration get byzantineCardStatic => const BoxDecoration(
    color: EkklisiaColors.bgMid,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    border: Border(
      top: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
      left: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
      right: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
      bottom: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
    ),
  );

  static const BoxDecoration headerDecorationStatic = BoxDecoration(
    gradient: EkklisiaColors.headerGradient,
    border: Border(
      bottom: BorderSide(color: EkklisiaColors.goldBorder, width: 0.5),
    ),
  );

  static const BoxDecoration parchmentDecorationStatic = BoxDecoration(
    color: EkklisiaColors.bgParchment,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    border: Border(
      top: BorderSide(color: EkklisiaColors.goldDim, width: 0.8),
      left: BorderSide(color: EkklisiaColors.goldDim, width: 0.8),
      right: BorderSide(color: EkklisiaColors.goldDim, width: 0.8),
      bottom: BorderSide(color: EkklisiaColors.goldDim, width: 0.8),
    ),
  );

  static const String lightBackgroundAsset = 'assets/images/bg1.png';

  /// Background image decoration for the light theme.
  static const BoxDecoration lightBackgroundDecoration = BoxDecoration(
    image: DecorationImage(
      image: AssetImage(lightBackgroundAsset),
      fit: BoxFit.cover,
    ),
  );
}
