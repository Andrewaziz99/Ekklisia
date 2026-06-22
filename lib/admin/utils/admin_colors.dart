// lib/admin/utils/admin_colors.dart
// ─────────────────────────────────────────────────────────────────────────────
// AdminC — brightness-aware color bundle for admin screens.
//
// Usage in any admin build() method:
//   final c = AdminC(Theme.of(context).brightness);
//   Container(color: c.bgDeep, ...)
//   TextFormField(decoration: c.inputDeco('Hint text'))
//
// This replaces the old pattern of `EkklisiaColors.X` (always dark) with
// brightness-responsive colors so the admin UI matches the current theme.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../core/theme/brightness_colors.dart';

const _kRadius = BorderRadius.all(Radius.circular(8));

class AdminC {
  AdminC(Brightness b)
      : bgDeep       = BrightnessColors.bgDeep(b),
        bgMid        = BrightnessColors.bgMid(b),
        bgElevated   = BrightnessColors.bgElevated(b),
        textPrimary  = BrightnessColors.textPrimary(b),
        textSecondary= BrightnessColors.textSecondary(b),
        gold         = BrightnessColors.gold(b),
        goldLight    = BrightnessColors.goldLight(b),
        goldBorder   = BrightnessColors.goldBorder(b),
        goldDim      = BrightnessColors.goldDim(b),
        goldSubtle   = BrightnessColors.goldSubtle(b),
        maroon       = BrightnessColors.maroon(b),
        maroonMid    = BrightnessColors.maroonMid(b),
        tealMid      = BrightnessColors.tealMid(b),
        plum         = BrightnessColors.plum(b),
        bronze       = BrightnessColors.bronze(b);

  final Color bgDeep;
  final Color bgMid;
  final Color bgElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color gold;
  final Color goldLight;
  final Color goldBorder;
  final Color goldDim;
  final Color goldSubtle;
  final Color maroon;
  final Color maroonMid;
  final Color tealMid;
  final Color plum;
  final Color bronze;

  // ── Shared decoration helpers ─────────────────────────────────────────────

  BorderSide get borderSide => BorderSide(color: goldBorder, width: 0.5);

  InputDecoration inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textSecondary, fontSize: 12),
        filled: true,
        fillColor: bgMid,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: _kRadius,
          borderSide: BorderSide(color: goldBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _kRadius,
          borderSide: BorderSide(color: goldBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _kRadius,
          borderSide: BorderSide(color: gold, width: 1),
        ),
      );
}
