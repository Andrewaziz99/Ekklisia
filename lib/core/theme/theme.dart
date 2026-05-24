import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

/// Centralised ThemeData + helpers.
/// All UI components in the app reference this — never hardcode colours.
class EkkleciaTheme {
  EkkleciaTheme._();

  // ── Text Styles ───────────────────────────────────────────────────────────

  /// App-bar / screen title — gold, wide letter-spacing
  static const TextStyle titleLarge = TextStyle(
    color: EkkleiciaColors.goldLight,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
  );

  /// Section heading — primary text
  static const TextStyle headingMedium = TextStyle(
    color: EkkleiciaColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle headingSmall = TextStyle(
    color: EkkleiciaColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Body text
  static const TextStyle bodyMedium = TextStyle(
    color: EkkleiciaColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    color: EkkleiciaColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Gold accent label
  static const TextStyle labelGold = TextStyle(
    color: EkkleiciaColors.gold,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  /// Arabic RTL body
  static const TextStyle arabicBody = TextStyle(
    fontFamily: 'Scheherazade',
    color: EkkleiciaColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.8,
  );

  /// Coptic liturgical text
  static const TextStyle copticBody = TextStyle(
    fontFamily: 'CopticFont',
    color: EkkleiciaColors.textPrimary,
    fontSize: 16,
    height: 1.8,
  );

  /// Greek text
  static const TextStyle greekBody = TextStyle(
    fontFamily: 'GFSDidot',
    color: EkkleiciaColors.textPrimary,
    fontSize: 16,
    height: 1.7,
  );

  // ── ThemeData ──────────────────────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: EkkleiciaColors.bgPrimary,
    primaryColor: EkkleiciaColors.gold,

    colorScheme: const ColorScheme.dark(
      primary: EkkleiciaColors.gold,
      secondary: EkkleiciaColors.maroon,
      surface: EkkleiciaColors.bgMid,
      onPrimary: EkkleiciaColors.bgDeep,
      onSecondary: EkkleiciaColors.textCream,
      onSurface: EkkleiciaColors.textPrimary,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: EkkleiciaColors.bgDeep,
      foregroundColor: EkkleiciaColors.goldLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: EkkleiciaColors.goldLight,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: EkkleiciaColors.bgDeep,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: EkkleiciaColors.gold),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: EkkleiciaColors.bgDeep,
      selectedItemColor: EkkleiciaColors.gold,
      unselectedItemColor: EkkleiciaColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    cardTheme: CardThemeData(
      color: EkkleiciaColors.bgMid,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EkkleiciaColors.gold,
        foregroundColor: EkkleiciaColors.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EkkleiciaColors.gold,
        side: const BorderSide(color: EkkleiciaColors.goldBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EkkleiciaColors.bgElevated,
      hintStyle: const TextStyle(color: EkkleiciaColors.textSecondary),
      labelStyle: const TextStyle(color: EkkleiciaColors.textSecondary),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: EkkleiciaColors.gold, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: EkkleiciaColors.goldBorder,
          width: 0.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: EkkleiciaColors.bgElevated,
      labelStyle: const TextStyle(
        color: EkkleiciaColors.textSecondary,
        fontSize: 11,
      ),
      selectedColor: EkkleiciaColors.goldSubtle,
      side: const BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    dividerTheme: const DividerThemeData(
      color: EkkleiciaColors.goldBorder,
      thickness: 0.5,
    ),

    iconTheme: const IconThemeData(color: EkkleiciaColors.gold),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: EkkleiciaColors.goldLight,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        color: EkkleiciaColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: EkkleiciaColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: EkkleiciaColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: EkkleiciaColors.textPrimary,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        color: EkkleiciaColors.textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: TextStyle(color: EkkleiciaColors.textSecondary, fontSize: 12),
      labelLarge: TextStyle(
        color: EkkleiciaColors.gold,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: EkkleiciaColors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    ),
  );

  // ── Convenience Decorations ───────────────────────────────────────────────

  /// Card decoration matching the Byzantine dark aesthetic
  static BoxDecoration get byzantineCard => BoxDecoration(
    color: EkkleiciaColors.bgMid,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: EkkleiciaColors.goldBorder, width: 0.5),
  );

  /// Gold-framed header with deep background gradient
  static BoxDecoration get headerDecoration => const BoxDecoration(
    gradient: EkkleiciaColors.headerGradient,
    border: Border(
      bottom: BorderSide(color: EkkleiciaColors.goldBorder, width: 0.5),
    ),
  );

  /// Parchment-style container for text content
  static BoxDecoration get parchmentDecoration => BoxDecoration(
    color: EkkleiciaColors.bgParchment,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: EkkleiciaColors.goldDim, width: 0.8),
    boxShadow: [
      BoxShadow(
        color: EkkleiciaColors.bgDeep.withOpacity(0.5),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
