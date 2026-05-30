// lib/core/theme/colors.dart
// ─────────────────────────────────────────────────────────────────────────────
// Ekklisia — Coptic App Color Palette
// Sacred Byzantine theme with light & dark mode support
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

abstract class EkklisiaColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME COLORS (Dark background, light text)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Dark Backgrounds ──────────────────────────────────────────────────────
  static const Color darkBgDeep        = Color(0xFF08111C);
  static const Color darkBgPrimary     = Color(0xFF0D1B2A);
  static const Color darkBgMid         = Color(0xFF162535);
  static const Color darkBgElevated    = Color(0xFF1E3448);
  static const Color darkBgParchment   = Color(0xFFEFE0BC);
  static const Color darkBgParchmentDim= Color(0xFFD9C89A);

  // ── Dark Gold Accents ─────────────────────────────────────────────────────
  static const Color darkGold          = Color(0xFFC8A84B);
  static const Color darkGoldLight     = Color(0xFFE2C87A);
  static const Color darkGoldDim       = Color(0xFF8B7035);
  static const Color darkGoldSubtle    = Color(0x12C8A84B);
  static const Color darkGoldBorder    = Color(0x59C8A84B);

  // ── Dark Category Colors ──────────────────────────────────────────────────
  static const Color darkMaroon        = Color(0xFF6B1A2A);
  static const Color darkMaroonMid     = Color(0xFF8B2238);
  static const Color darkMaroonDark    = Color(0xFF4A1120);
  static const Color darkTealDark      = Color(0xFF0F4A3C);
  static const Color darkTealMid       = Color(0xFF156B55);
  static const Color darkPlum          = Color(0xFF3D2860);
  static const Color darkPlumDark      = Color(0xFF2A1A40);
  static const Color darkForest        = Color(0xFF3A5E1A);
  static const Color darkOcean         = Color(0xFF1A3D5A);
  static const Color darkBronze        = Color(0xFF7A5A1A);
  static const Color darkBronzeDark    = Color(0xFF5C4010);
  static const Color darkTealOcean     = Color(0xFF1A5E5E);

  // ── Dark Text ─────────────────────────────────────────────────────────────
  static const Color darkTextPrimary    = Color(0xFFF0E6C8);
  static const Color darkTextSecondary  = Color(0xFFA89060);
  static const Color darkTextCream      = Color(0xFFF5EDDA);
  static const Color darkTextCreamDim   = Color(0xFFD9C89A);
  static const Color darkTextOnParchment= Color(0xFF2A1A08);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS (Light background, dark text)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Light Backgrounds ─────────────────────────────────────────────────────
  static const Color lightBgDeep        = Color(0xFFFAF8F4);
  static const Color lightBgPrimary     = Color(0xFFFFFFFF);
  static const Color lightBgMid         = Color(0xFFF5F2ED);
  static const Color lightBgElevated    = Color(0xFFEFEBE6);
  static const Color lightBgParchment   = Color(0xFFEFE0BC);
  static const Color lightBgParchmentDim= Color(0xFFD9C89A);

  // ── Light Gold Accents ────────────────────────────────────────────────────
  static const Color lightGold          = Color(0xFF8B7035);
  static const Color lightGoldLight     = Color(0xFFC8A84B);
  static const Color lightGoldDim       = Color(0xFF5C4010);
  static const Color lightGoldSubtle    = Color(0x12C8A84B);
  static const Color lightGoldBorder    = Color(0x99C8A84B);

  // ── Light Category Colors ─────────────────────────────────────────────────
  static const Color lightMaroon        = Color(0xFF8B2238);
  static const Color lightMaroonMid     = Color(0xFFA83D52);
  static const Color lightMaroonDark    = Color(0xFF6B1A2A);
  static const Color lightTealDark      = Color(0xFF156B55);
  static const Color lightTealMid       = Color(0xFF1E8B6E);
  static const Color lightPlum          = Color(0xFF5C4080);
  static const Color lightPlumDark      = Color(0xFF3D2860);
  static const Color lightForest        = Color(0xFF5A7A2A);
  static const Color lightOcean         = Color(0xFF2A5D8B);
  static const Color lightBronze        = Color(0xFF9B7A2A);
  static const Color lightBronzeDark    = Color(0xFF7A5A1A);
  static const Color lightTealOcean     = Color(0xFF2A7D7D);

  // ── Light Text ────────────────────────────────────────────────────────────
  static const Color lightTextPrimary    = Color(0xFF1A1410);
  static const Color lightTextSecondary  = Color(0xFF5C4A38);
  static const Color lightTextCream      = Color(0xFF2A1A08);
  static const Color lightTextCreamDim   = Color(0xFF5C4A38);
  static const Color lightTextOnParchment= Color(0xFF2A1A08);

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKWARDS COMPATIBILITY (defaults to dark)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color bgDeep        = darkBgDeep;
  static const Color bgPrimary     = darkBgPrimary;
  static const Color bgMid         = darkBgMid;
  static const Color bgElevated    = darkBgElevated;
  static const Color bgParchment   = darkBgParchment;
  static const Color bgParchmentDim= darkBgParchmentDim;

  // ── Gold Accents ──────────────────────────────────────────────────────────
  static const Color gold          = darkGold;
  static const Color goldLight     = darkGoldLight;
  static const Color goldDim       = darkGoldDim;
  static const Color goldSubtle    = darkGoldSubtle;
  static const Color goldBorder    = darkGoldBorder;

  // ── Category Colors ───────────────────────────────────────────────────────
  static const Color maroon        = darkMaroon;
  static const Color maroonMid     = darkMaroonMid;
  static const Color maroonDark    = darkMaroonDark;
  static const Color tealDark      = darkTealDark;
  static const Color tealMid       = darkTealMid;
  static const Color plum          = darkPlum;
  static const Color plumDark      = darkPlumDark;
  static const Color forest        = darkForest;
  static const Color ocean         = darkOcean;
  static const Color bronze        = darkBronze;
  static const Color bronzeDark    = darkBronzeDark;
  static const Color tealOcean     = darkTealOcean;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary    = darkTextPrimary;
  static const Color textSecondary  = darkTextSecondary;
  static const Color textCream      = darkTextCream;
  static const Color textCreamDim   = darkTextCreamDim;
  static const Color textOnParchment= darkTextOnParchment;

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient darkHeaderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgDeep, darkBgPrimary],
  );

  static const LinearGradient darkBottomNavGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgMid, darkBgDeep],
  );

  static const LinearGradient darkCardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xC5000000)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient darkSplashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgDeep, darkBgPrimary, darkBgMid],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient darkMaroonCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A0D14), darkMaroon],
  );

  static const LinearGradient darkPlumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkPlumDark, darkPlum],
  );

  static const LinearGradient darkBronzeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBronzeDark, darkBronze],
  );

  static const RadialGradient darkNavCenterButtonGradient = RadialGradient(
    colors: [darkBronze, darkMaroon],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient lightHeaderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgElevated, lightBgMid],
  );

  static const LinearGradient lightBottomNavGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgMid, lightBgElevated],
  );

  static const LinearGradient lightCardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x26000000)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient lightSplashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgElevated, lightBgMid, lightBgDeep],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient lightMaroonCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8D5DC), lightMaroon],
  );

  static const LinearGradient lightPlumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6DFF0), lightPlum],
  );

  static const LinearGradient lightBronzeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEDE5D5), lightBronze],
  );

  static const RadialGradient lightNavCenterButtonGradient = RadialGradient(
    colors: [lightBronze, lightMaroon],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKWARDS COMPATIBILITY (defaults to dark)
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient headerGradient = darkHeaderGradient;
  static const LinearGradient bottomNavGradient = darkBottomNavGradient;
  static const LinearGradient cardOverlayGradient = darkCardOverlayGradient;
  static const LinearGradient splashGradient = darkSplashGradient;
  static const LinearGradient maroonCardGradient = darkMaroonCardGradient;
  static const LinearGradient plumCardGradient = darkPlumCardGradient;
  static const LinearGradient bronzeCardGradient = darkBronzeCardGradient;
  static const RadialGradient navCenterButtonGradient = darkNavCenterButtonGradient;
}