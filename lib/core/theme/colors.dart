// lib/core/theme/ekklecia_colors.dart
// ─────────────────────────────────────────────────────────────────────────────
// Ekklicia — Coptic App Color Palette
// Sacred Byzantine dark theme inspired by illuminated manuscripts,
// gold leaf iconography, and Coptic Orthodox liturgical aesthetics.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

abstract class EkkleiciaColors {

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color bgDeep        = Color(0xFF08111C);
  static const Color bgPrimary     = Color(0xFF0D1B2A);
  static const Color bgMid         = Color(0xFF162535);
  static const Color bgElevated    = Color(0xFF1E3448);
  static const Color bgParchment   = Color(0xFFEFE0BC);
  static const Color bgParchmentDim= Color(0xFFD9C89A);

  // ── Gold Accents ──────────────────────────────────────────────────────────
  static const Color gold          = Color(0xFFC8A84B);
  static const Color goldLight     = Color(0xFFE2C87A);
  static const Color goldDim       = Color(0xFF8B7035);
  static const Color goldSubtle    = Color(0x12C8A84B);
  static const Color goldBorder    = Color(0x59C8A84B);

  // ── Category Colors ───────────────────────────────────────────────────────
  static const Color maroon        = Color(0xFF6B1A2A);
  static const Color maroonMid     = Color(0xFF8B2238);
  static const Color maroonDark    = Color(0xFF4A1120);
  static const Color tealDark      = Color(0xFF0F4A3C);
  static const Color tealMid       = Color(0xFF156B55);
  static const Color plum          = Color(0xFF3D2860);
  static const Color plumDark      = Color(0xFF2A1A40);
  static const Color forest        = Color(0xFF3A5E1A);
  static const Color ocean         = Color(0xFF1A3D5A);
  static const Color bronze        = Color(0xFF7A5A1A);
  static const Color bronzeDark    = Color(0xFF5C4010);
  static const Color tealOcean     = Color(0xFF1A5E5E);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF0E6C8);
  static const Color textSecondary  = Color(0xFFA89060);
  static const Color textCream      = Color(0xFFF5EDDA);
  static const Color textCreamDim   = Color(0xFFD9C89A);
  static const Color textOnParchment= Color(0xFF2A1A08);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDeep, bgPrimary],
  );

  static const LinearGradient bottomNavGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgMid, bgDeep],
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xC5000000)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDeep, bgPrimary, bgMid],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient maroonCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A0D14), maroon],
  );

  static const LinearGradient plumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [plumDark, plum],
  );

  static const LinearGradient bronzeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bronzeDark, bronze],
  );

  static const RadialGradient navCenterButtonGradient = RadialGradient(
    colors: [bronze, maroon],
  );
}